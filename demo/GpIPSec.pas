(*:IP address filtering. Supporting class for TGpProxy and other components.
   @author Primoz Gabrijelcic [gabr@17slon.com]
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2004, Primoz Gabrijelcic
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- The name of the Primoz Gabrijelcic may not be used to endorse or promote
  products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

   Author            : Primoz Gabrijelcic [gabr@17slon.com]
   Creation date     : 2001-06-27
   Last modification : 2004-03-17
   Version           : 1.03
</pre>*)(*
   History:
     1.03: 2004-03-17
       - Pulled in from another (commercial) project.
     1.02: 2003-07-31
       - Added class functions TGpIPSec.ParseNetmask, TGpIPSec.Resolve,
         and TGpIPSec.SameSubnet.
     1.01a: 2003-05-10
       - Bug fixed: After AllowedIP property was loaded directly from file
         (AllowedIP.LoadFromFile), it was not reparsed.
     1.01: 2002-07-21       
       - Function TGpIPSec.IsValidMask changed into class function and
         made public.
     1.0: 2001-06-28
       - Released.
     0.1: 2001-06-27
       - Created.
*)

unit GpIPSec;

interface

uses
  Classes,
  Contnrs,
  WinSock;

const
  {:Special value representing all local IP addresses.
  }
  CLocalhost = 'localhost';

type
  {:IP address/mask pair.
  }
  TGpIPMask = class
  private
    FAddress: u_long;
    FMask   : u_long;
  public
    constructor Create(address, mask: u_long);
    function  Matches(IPAddr: u_long): boolean;
    property  Address: u_long read FAddress;
    property  Mask: u_long read FMask;
  end; { TGpIPMask }

  {:List of IP address/mask pairs.
  }
  TGpIPMaskList = class
  private
    FList: TObjectList;
    function GetItem(idx: integer): TGpIPMask; // of TGpIPMask
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Add(address, mask: u_long);
    procedure Clear;
    function  Count: integer;
    function  IsInList(address, mask: u_long): boolean;
    function  Matches(IPAddr: u_long): boolean;
    property  Items[idx: integer]: TGpIPMask read GetItem;
  end; { TGpIPMaskList }

  {:IP filtering class. Stores list of allowed IP addresses in parsed form.
    Can quickly determine if a given IP address is in the allowed list.
  }
  TGpIPSec = class
  private
    FAllowedIP  : TStrings;
    FAllowedList: TGpIPMaskList;
  protected
    procedure AllowAllInList(IPList: TStrings; allowLocalhost: boolean); virtual;
    procedure AllowedIPListChanged(Sender: TObject); virtual;
    function  AllowIP(IPaddr, IPmask: string): boolean; virtual;
    procedure ClearTables; virtual;
    procedure ParseAllowedIP; virtual;
    procedure SetAllowedIP(const Value: TStrings); virtual;
  public
    constructor Create;
    destructor  Destroy; override;
    class function IsValidMask(mask: u_long): boolean; virtual;
    class function ParseNetmask(const netmask: string): u_long; virtual;
    class function Resolve(const address: string): u_long; virtual;
    class function SameSubnet(address1, address2, netmask: u_long): boolean; virtual;
    function  IsAllowed(IPAddr: string): boolean;
    {:List of the IP addresses allowed to access the proxy. Each line should
      contain:
      - string 'localhost' (macro for all server IP addresses)
      - host name 'my.host.com'
      - IP address 'xxx.yyy.www.zzz'
      - IP address + mask 'xxx.yyy.www.zzz/nnn.nnn.nnn.nnn'
    }
    property  AllowedIP: TStrings read FAllowedIP write SetAllowedIP;
  end; { TGpIPSec }

implementation

uses
  SysUtils,
  WSocket,
  GpString;

{ TGpIPSec }

{:Add all IP addresses in the list to the 'allowed' table.
  @param   IPList         List of the allowed IP addresses, optionally including
                          mask to specify subnet.
  @param   allowLocalHost Set to True to allow special entry CLocalhost to
                          appear in the IPList. It will be replaced with all
                          local IP addresses.
}
procedure TGpIPSec.AllowAllInList(IPList: TStrings; allowLocalhost: boolean);
var
  iIP   : integer;
  okIP  : boolean;
  thisIP: string;
begin
  iIP := 0;
  while iIP < IPList.Count do begin
    thisIP := IPList[iIP];
    if allowLocalHost and SameText(thisIP,CLocalhost) then begin
      AllowAllInList(LocalIPList,false);
      okIP := AllowIP('127.0.0.1','255.255.255.255');
    end
    else if Pos('/',thisIP) = 0 then
      okIP := AllowIP(thisIP,'255.255.255.255')
    else if NumElements(thisIP,'/',-1) = 2 then
      okIP := AllowIP(FirstEl(thisIP,'/',-1),LastEl(thisIP,'/',-1))
    else
      okIP := false;
    if okIP then
      Inc(iIP)
    else // remove bad entry from the list
      IPList.Delete(iIP);
  end; //for
end; { TGpIPSec.AllowAllInList }

procedure TGpIPSec.AllowedIPListChanged(Sender: TObject);
begin
  ParseAllowedIP;
end; { TGpIPSec.AllowedIPListChanged }

{:Add specified subnet to the list of the allowed addresses.
  @param   IPaddr Allowed IP address.
  @param   IPmask Mask for the IPaddr.
  @returns True if address and mask were properly formatted.
}
function TGpIPSec.AllowIP(IPaddr, IPmask: string): boolean;
var
  address: u_long;
  mask   : u_long;
begin
  Result := false;
  try
    address := Resolve(IPaddr);
    mask := ParseNetmask(IPmask);
    if mask = 0 then
      Exit;
    FAllowedList.Add(address, mask);
    Result := true;
  except
    on ESocketException do
      ;
  end;
end; { TGpIPSec.AllowIP }

{:Clear local tables.
}
procedure TGpIPSec.ClearTables;
begin
  FAllowedList.Clear;
end; { TGpIPSec.ClearTables }

constructor TGpIPSec.Create;
begin
  FAllowedIP := TStringList.Create;
  (FAllowedIP as TStringList).OnChange := AllowedIPListChanged;
  FAllowedList := TGpIPMaskList.Create;
end; { TGpIPSec.Create }

destructor TGpIPSec.Destroy;
begin
  FreeAndNil(FAllowedList);
  FreeAndNil(FAllowedIP);
end; { TGpIPSec.Destroy }

{:Check if the IP address is in the list of allowed IP addresses.
  @param   IPaddr IP address to be checked. Can be specified in the dotted
                  representation or as a host name (which will be resolved
                  first).
  @returns True if IP address is in the list of allowed IP addresses.
}
function TGpIPSec.IsAllowed(IPAddr: string): boolean;
begin
  Result := false;
  try
    Result := FAllowedList.Matches(htonl(WSocketResolveHost(IPaddr).s_addr));
  except
    on ESocketException do
      ;
  end;
end; { TGpIPSec.IsAllowed }

{:Check if parameter is a valid IP mask.
  @param   mask IP mask.
  @returns True if parameter is a valid IP mask.
}
class function TGpIPSec.IsValidMask(mask: u_long): boolean;
var
  iBit   : integer;
  leftBit: boolean;
begin
  // Valid network mask must have ones on the left and zeros on the right.
  Result := true; // handle 255.255.255.255 case
  for iBit := 0 to 31 do begin
    leftBit := ((mask AND $80000000) <> 0);
    mask := mask SHL 1;
    if not leftBit then begin
      Result := (mask = 0);
      break; //for
    end;
  end; //for
end; { TGpIPSec.IsValidMask }

{:Parse list of allowed IP addresses for faster access.
}
procedure TGpIPSec.ParseAllowedIP;
begin
  ClearTables;
  AllowAllInList(FAllowedIP,true);
end; { TGpIPSec.ParseAllowedIP }

{:Converts netmask into numeric representation.
  @since   2003-07-31
}
class function TGpIPSec.ParseNetmask(const netmask: string): u_long;
begin
  Result := 0;
  if not WSocketIsDottedIP(netmask) then
    Exit;
  Result := htonl(WSocketResolveHost(netmask).s_addr);
  if not IsValidMask(Result) then
    Result := 0;
end; { TGpIPSec.ParseNetmask }

{:Resolves address into numeric representation.
  @since   2003-07-31
}
class function TGpIPSec.Resolve(const address: string): u_long;
begin
  Result := htonl(WSocketResolveHost(address).s_addr);
end; { TGpIPSec.Resolve }

{:Check if two addresses belong to the same netmask.
}
class function TGpIPSec.SameSubnet(address1, address2,
  netmask: u_long): boolean;
begin
  Result := (address1 AND netmask) = (address2 AND netmask);
end; { TGpIPSec.SameSubnet }

{:Set list of allowed IP addresses.
}
procedure TGpIPSec.SetAllowedIP(const Value: TStrings);
begin
  if FAllowedIP <> Value then
    FAllowedIP.Assign(Value);
end; { TGpIPSec.SetAllowedIP }

{ TGpIPMask }

constructor TGpIPMask.Create(address, mask: u_long);
begin
  FAddress := address AND mask;
  FMask := mask;
end; { TGpIPMask.Create }

{:Check if address/mask pair matches specified IP address (in other words -
  check if IP address belongs to the subnet specified by the address/mask pair).
  @param   IPaddr IP address to be checked.
  @returns True if address/mask pair mathes the IP address.
}
function TGpIPMask.Matches(IPAddr: u_long): boolean;
begin
  Result := (FAddress = (IPAddr AND FMask));
end; { TGpIPMask.Matches }

{ TGpIPMaskList }

{:Add address/mask pair to the list.
  @param   address IP address.
  @param   mask    Mask for this IP address.
}
procedure TGpIPMaskList.Add(address, mask: u_long);
begin
  FList.Add(TGpIPMask.Create(address,mask));
end; { TGpIPMaskList.Add }

{:Clear the list.
}
procedure TGpIPMaskList.Clear;
begin
  FList.Clear;
end; { TGpIPMaskList.Clear }

{:Get number of address/mask pairs in the list.
}
function TGpIPMaskList.Count: integer;
begin
  Result := FList.Count;
end; { TGpIPMaskList.Count }

constructor TGpIPMaskList.Create;
begin
  FList := TObjectList.Create;
end; { TGpIPMaskList.Create }

destructor TGpIPMaskList.Destroy;
begin
  FreeAndNil(FList);
end; { TGpIPMaskList.Destroy }

{:Retrieve list item.
  @param   idx Item index (0-based).
}
function TGpIPMaskList.GetItem(idx: integer): TGpIPMask;
begin
  Result := (FList[idx] as TGpIPMask);
end; { TGpIPMaskList.GetItem }

{:Check if address/mask pair is already in the list.
  @param   address IP address.
  @param   mask    Mask for this IP address.
  @returns True if address/mask pair is already in the list.
}
function TGpIPMaskList.IsInList(address, mask: u_long): boolean;
var
  iPair: integer;
begin
  Result := false;
  for iPair := 0 to Count-1 do begin
    if (Items[iPair].Address = address) and (Items[iPair].Mask = mask) then begin
      Result := true;
      break; //for
    end;
  end; //for
end; { TGpIPMaskList.IsInList }

{:Check if any address/mask pair in the list matches specified IP address (in
  other words - check if IP address belongs to the subnet specified by any
  address/mask pair in the list).
  @param   IPaddr IP address to be checked.
  @returns True if address/mask pair mathes the IP address.
}
function TGpIPMaskList.Matches(IPAddr: u_long): boolean;
var
  iPair: integer;
begin
  if Count = 0 then
    Result := true
  else begin
    Result := false;
    for iPair := 0 to Count-1 do begin
      if Items[iPair].Matches(IPAddr) then begin
        Result := true;
        break; //for
      end;
    end; //for
  end;
end; { TGpIPMaskList.Matches }

end.
