(*:Proxy description, ready to become a subcomponent of any component.
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
   Creation date     : 2001-06-28
   Last modification : 2004-03-17
   Version           : 1.01
</pre>*)(*
   History:
     1.01: 2004-03-17
       - Pulled in from another (commercial) project.
     1.0: 2001-06-28
       - Created & released.
*)

unit GpProxyData;

interface

uses
  Classes;

type
  {:Data describing proxy. 
  }                          
  TGpProxyData = class(TPersistent)
  private
    FAddress : string;
    FOnChange: TNotifyEvent;
    FPassword: string;
    FPort    : integer;
    FUsername: string;
  protected
    procedure DoChange; virtual;
    procedure SetAddress(const Value: string); virtual;
    procedure SetPassword(const Value: string); virtual;
    procedure SetPort(const Value: integer); virtual;
    procedure SetUsername(const Value: string); virtual;
  public
    constructor Create(defaultPort: integer);
    procedure Assign(Source: TPersistent); override;
  published
    {:Proxy address (host name or dotted IP address).}
    property  Address: string read FAddress write SetAddress;
    {:Proxy password (if required).}
    property  Password: string read FPassword write SetPassword;
    {:Proxy port.}
    property  Port: integer read FPort write SetPort;
    {:Proxy username (if required.}
    property  Username: string read FUsername write SetUsername;
    {:OnChange event triggers everytime any other property is modified.}
    property  OnChange: TNotifyEvent read FOnChange write FOnChange;
  end; { TGpProxyData }

implementation

{ TGpProxyData }

procedure TGpProxyData.Assign(Source: TPersistent);
begin
  if Source is TGpProxyData then begin
    FAddress  := TGpProxyData(Source).FAddress;
    FPort     := TGpProxyData(Source).FPort;
    FUsername := TGpProxyData(Source).FUsername;
    FPassword := TGpProxyData(Source).FPassword;
  end
  else
    inherited;
end; { TGpProxyData.Assign }

constructor TGpProxyData.Create(defaultPort: integer);
begin
  FPort := defaultPort;
end; { TGpProxyData.Create }

procedure TGpProxyData.DoChange;
begin
  if assigned(FOnChange) then
    FOnChange(Self);
end; { TGpProxyData.SetAddress }

procedure TGpProxyData.SetAddress(const Value: string);
begin
  if FAddress <> Value then begin
    FAddress := Value;
    DoChange;
  end;
end; { TGpProxyData.SetAddress }

procedure TGpProxyData.SetPassword(const Value: string);
begin
  if FPassword <> Value then begin
    FPassword := Value;
    DoChange;
  end;
end; { TGpProxyData.SetPassword }

procedure TGpProxyData.SetPort(const Value: integer); 
begin
  if FPort <> Value then begin
    FPort := Value;
    DoChange;
  end;
end; { TGpProxyData.SetPort }

procedure TGpProxyData.SetUsername(const Value: string);
begin
  if FUsername <> Value then begin
    FUsername := Value;
    DoChange;
  end;
end; { TGpProxyData.SetUsername }

end.
