{*_* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

Author:       Fran?ois PIETTE
Description:  A TWSocket that has server functions: it listen to connections
              an create other TWSocket to handle connection for each client.
Creation:     Dec 2003 from win32 version created aug 29, 1999
Version:      5.02
EMail:        http://www.overbyte.be       francois.piette@overbyte.be
              http://www.rtfm.be/fpiette   francois.piette@rtfm.be
Support:      Use the mailing list twsocket@elists.org
              Follow "support" link at http://www.overbyte.be for subscription.
Legal issues: Copyright (C) 1999-2005 by Fran?ois PIETTE
              Rue de Grady 24, 4053 Embourg, Belgium. Fax: +32-4-365.74.56
              <francois.piette@pophost.eunet.be><francois.piette@swing.be>

              This software is provided 'as-is', without any express or
              implied warranty.  In no event will the author be held liable
              for any  damages arising from the use of this software.

              Permission is granted to anyone to use this software for any
              purpose, including commercial applications, and to alter it
              and redistribute it freely, subject to the following
              restrictions:

              1. The origin of this software must not be misrepresented,
                 you must not claim that you wrote the original software.
                 If you use this software in a product, an acknowledgment
                 in the product documentation would be appreciated but is
                 not required.

              2. Altered source versions must be plainly marked as such, and
                 must not be misrepresented as being the original software.

              3. This notice may not be removed or altered from any source
                 distribution.

              4. You must register this software by sending a picture postcard
                 to the author. Use a nice stamp and mention your name, street
                 address, EMail address and any comment you like to say.

Quick reference guide:
TWSocketServer will normally be used to listen on a given tcp port. When a
client connect, it will instanciate a new TWSocketClient component to handle
communication with client. Normally you will derive your own component from
TWSocketClient to add private data and methods to handle it. You tell
TWSocketServer which component it has to instanciate using ClientClass
property. You have to initialize instances from OnClientConnect event handler.
TWSocketServer maintain a list of connected clients. You can access it using
Client[] indexed property and ClientCount property.

History:
Sep 05, 1999 V1.01 Adpted for Delphi 1
Oct 09, 1999 V1.02 Added intermediate class TCustomWSocket
Nov 12, 1999 V1.03 Added OnClientCreate event just after client component has
                   been created.
Apr 02, 2000 V1.04 Added FSessionClosedFlag to avoid double SessionClosed
                   event triggering
Apr 13, 2002 V1.05 When sending banner to client, add LineEnd instead of CR/LF
                   as suggested by David Aguirre Grazio <djagra@xaire.com>
Sep 13, 2002 V1.06 Check if Assigned(Server) in TriggerSessionClosed.
                   Reported by Matthew Meadows <matthew.meadows@inquisite.com>
Sep 16, 2002 V1.07 Fixed a Delphi 1 issue in TriggerSessionClosed where
                   property was used in place of field variable.
Jan 04, 2003 V1.08 Renamed BannerToBusy to BannerTooBusy. This will cause
                   trouble in applications already using this property. You
                   have to rename the property in your app !
Jan 24, 2003 V5.00 Skipped to version 5 because of SSL code
Jan 26, 2004 V5.01 Introduced ICSDEFS.INC and reordered uses for FPC
                   compatibility.
Mai 01, 2004 V5.02 WMClientClosed was incorrectly referencing global Error
                   variable instead of the real winsock error code. Now pass
                   the errcode in WParam at the time of PostMessage.
                   Removed Forms and Graphics units from the uses clause.


 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
unit OverByte.Ics.WSocketServer platform;

interface

uses
    System.Runtime.InteropServices,
    Borland.Vcl.SysUtils,
    Borland.Vcl.Windows,
    Borland.Vcl.Messages,
    Borland.Vcl.Classes,
    OverByte.Ics.Component,
    OverByte.Ics.WSocket,
    OverByte.Ics.WinSock;

const
    WSocketServerVersion     = 600;
    CopyRight : String       = ' TWSocketServer (c) 1999-2005 F. Piette V6.00.0 ';
    WM_CLIENT_CLOSED         = WM_USER + 30;
    DefaultBanner            = 'Welcome to TcpSrv';

type
    TCustomWSocketServer       = class;
    TWSocketClient             = class;
    TWSocketClientClass        = class of TWSocketClient;
    TWSocketClientCreateEvent  = procedure (Sender  : TObject;
                                            Client  : TWSocketClient) of object;
    TWSocketClientConnectEvent = procedure (Sender  : TObject;
                                            Client  : TWSocketClient;
                                            ErrCode : Word) of object;

    { TWSocketClient is used to handle all client connections.           }
    { Altough you may use it directly, you'll probably wants to use your }
    { own derived component to add data and methods suited to your       }
    { application.                                                       }
    { If you use a derived component, then assign it's class to          }
    { TWSocketServer ClientClass property.                               }
    TWSocketClient = class(TWSocket)
    protected
        FBanner            : String;
        FServer            : TCustomWSocketServer;
        //FMyGCH             : GCHandle;
        FClientNum         : Integer;
        FPeerAddr          : String;
        FPeerPort          : String;
        FSessionClosedFlag : Boolean;
        procedure   TriggerSessionClosed(Error : Word); override;
    public
        procedure   StartConnection; virtual;
        procedure   Dup(newHSocket : TSocket); override;
        function    GetPeerAddr: String; override;
        function    GetPeerPort: String; override;
        property    Server : TCustomWSocketServer read  FServer
                                                  write FServer;
        //property    MyGCH  : GCHandle             read  FMyGCH
        //                                          write FMyGCH;
        property    ClientNum : Integer           read  FClientNum
                                                  write FClientNum;
    published
        property Banner : String           read  FBanner
                                           write FBanner;
    end;

    { TWSocketServer is made for listening for tcp client connections.      }
    { For each connection, it instanciate a new TWSocketClient (or derived) }
    { to handle connection. Use ClientClass to specify your derived.        }
    TCustomWSocketServer = class(TWSocket)
    protected
        FBanner                 : String;
        FBannerTooBusy          : String;
        FClientClass            : TWSocketClientClass;
        FClientList             : TList;
        FClientNum              : LongInt;
        FMaxClients             : LongInt;
        FOnClientCreate         : TWSocketClientCreateEvent;
        FOnClientConnect        : TWSocketClientConnectEvent;
        FOnClientDisconnect     : TWSocketClientConnectEvent;
        procedure WndProc(var MsgRec: TMessage); override;
        procedure TriggerSessionAvailable(Error : Word); override;
        procedure TriggerClientCreate(Client : TWSocketClient); virtual;
        procedure TriggerClientConnect(Client : TWSocketClient; Error : Word); virtual;
        procedure TriggerClientDisconnect(Client : TWSocketClient; Error : Word); virtual;
        function  GetClientCount : Integer; virtual;
        function  GetClient(nIndex : Integer) : TWSocketClient; virtual;
        procedure Notification(AComponent: {$IFDEF ICS_COMPONENT}TComponent{$ELSE}TIcsComponent{$ENDIF};
                               Operation: TOperation); override;
        procedure WMClientClosed(var msg: TMessage);
                                 //message WM_CLIENT_CLOSED;
    public
        constructor Create(AOwner: {$IFDEF ICS_COMPONENT}TComponent
                                   {$ELSE}TObject{$ENDIF}); override;
        destructor  Destroy; override;
        { Check  if a given object is one of our clients }
        function  IsClient(SomeThing : TObject) : Boolean;
    protected
        { TWSocketClient derived class to instanciate for each client }
        property  ClientClass            : TWSocketClientClass
                                                      read  FClientClass
                                                      write FClientClass;
        { How many active clients we currently have }
        property  ClientCount   : Integer             read  GetClientCount;
        { Client[] give direct access to anyone of our clients }
        property  Client[nIndex : Integer] : TWSocketClient
                                                      read  GetClient;
    published
        { Banner sent to client as welcome message. Can be empty. }
        property  Banner                 : String     read  FBanner
                                                      write FBanner;
        property  BannerTooBusy          : String     read  FBannerTooBusy
                                                      write FBannerTooBusy;
        property  MaxClients             : LongInt    read  FMaxClients
                                                      write FMaxClients;
        { Triggered when a client disconnect }
        property  OnClientDisconnect     : TWSocketClientConnectEvent
                                                      read  FOnClientDisconnect
                                                      write FOnClientDisconnect;
        { Triggerred when a new client is connecting }
        property  OnClientConnect        : TWSocketClientConnectEvent
                                                      read  FOnClientConnect
                                                      write FOnClientConnect;
        { Triggerred when a new client component has been created }
        property  OnClientCreate         : TWSocketClientCreateEvent
                                                      read  FOnClientCreate
                                                      write FOnClientCreate;
    end;

    TWSocketServer = class(TCustomWSocketServer)
    public
        property  ClientClass;
        property  ClientCount;
        property  Client;
    published
        property  Banner;
        property  BannerTooBusy;
        property  MaxClients;
        property  OnClientDisconnect;
        property  OnClientConnect;
    end;

implementation


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
constructor TCustomWSocketServer.Create(
    AOwner: {$IFDEF ICS_COMPONENT}TComponent
            {$ELSE}               TObject{$ENDIF});
begin
    inherited Create(AOwner);
    FClientList      := TList.Create;
    FClientClass     := TWSocketClient;
    FBanner          := DefaultBanner;
    FBannerTooBusy   := 'Sorry, too many clients';
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
destructor TCustomWSocketServer.Destroy;
var
    I      : Integer;
    Client : TWSocketClient;
begin
    if Assigned(FClientList) then begin
        { We need to destroy all clients }
        for I := FClientList.Count - 1 downto 0 do begin
            try
                Client := FClientList.Items[I] as TWSocketClient;
                //Client.MyGCH.Free;
                Client.Free;
            except
                { Ignore any exception here }
            end;
        end;
        { Then we can destroy client list }
        FClientList.Free;
        FClientList := nil;
    end;
    { And finally destroy ourself }
    inherited Destroy;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Message handler                                                           }
procedure TCustomWSocketServer.WndProc(var MsgRec: TMessage);
begin
    with MsgRec do begin
        if Msg = WM_CLIENT_CLOSED then begin
            { We *MUST* handle all exception to avoid application shutdown }
            try
                WMClientClosed(MsgRec)
            except
                on E:Exception do
                    HandleBackGroundException(E);
            end;
        end
        else
            inherited WndProc(MsgRec);
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Called by destructor when child component (a clients) is create or        }
{ destroyed.                                                                }
procedure TCustomWSocketServer.Notification(
    AComponent : {$IFDEF ICS_COMPONENT}TComponent{$ELSE}TIcsComponent{$ENDIF};
    Operation  : TOperation);
begin
    //MessageBox(0, 'TCustomWSocketServer.Notification', '', MB_OK);
    inherited Notification(AComponent, Operation);
    if Assigned(FClientList) and (AComponent is TWSocketClient) then begin
        if Operation = opInsert then
            { A new client has been created, add it to our list }
            FClientList.Add(AComponent)
        else if Operation = opRemove then
            { If one of our client has been destroyed, remove it from our list }
            FClientList.Remove(AComponent);
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Called when a session is available, that is when a client is connecting   }
procedure TCustomWSocketServer.TriggerSessionAvailable(Error : Word);
var
    Client : TWSocketClient;
begin
    { Call parent event handler }
    inherited TriggerSessionAvailable(Error);
    { In case of error, do nothing }
    if Error <> 0 then
        Exit;

    Inc(FClientNum);
    Client                 := FClientClass.Create(Self);
//    FClientList.Add(Client);    //******* Notification
    TriggerClientCreate(Client);
    Client.Name            := Name + 'Client' + IntToStr(FClientNum);
    Client.ClientNum       := FClientNum;
    Client.Banner          := FBanner;
    Client.Server          := Self;
    Client.HSocket         := Accept;
    TriggerClientConnect(Client, Error);
    { The event handler may have destroyed the client ! }
    if FClientList.IndexOf(Client) < 0 then
        Exit;
    { The event handler may have closed the connection }
    if Client.State <> wsConnected then
        Exit;
    { Ok, the client is still there, process with the connection }
    if (FMaxClients > 0) and (FMaxClients < ClientCount) then begin
        { Sorry, toomuch clients }
        Client.Banner := FBannerTooBusy;
        Client.StartConnection;
        Client.Close;
    end
    else
        Client.StartConnection;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TCustomWSocketServer.TriggerClientConnect(
    Client : TWSocketClient; Error : Word);
begin
    if Assigned(FOnClientConnect) then
        FOnClientConnect(Self, Client, Error);
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TCustomWSocketServer.TriggerClientCreate(Client : TWSocketClient);
begin
    if Assigned(FOnClientCreate) then
        FOnClientCreate(Self, Client);
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TCustomWSocketServer.TriggerClientDisconnect(
    Client : TWSocketClient; Error : Word);
begin
    if Assigned(FOnClientDisconnect) then
        FOnClientDisconnect(Self, Client, Error);
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ get number of connect clients                                               }
function TCustomWSocketServer.GetClientCount : Integer;
begin
    if Assigned(FClientList) then
        Result := FClientList.Count
    else
        Result := 0;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Acces method to return a client by index.                                   }
{ Return nil if index is out of range.                                        }
function TCustomWSocketServer.GetClient(nIndex : Integer) : TWSocketClient;
begin
    if not Assigned(FClientList) then begin
        Result := nil;
        Exit;
    end;
    if (nIndex < 0) or (nIndex >= FClientList.Count) then begin
        Result := nil;
        Exit;
    end;
    Result := TWSocketClient(FClientList.Items[nIndex]);
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Client has closed. Remove it from client list and destroy component.        }
procedure TCustomWSocketServer.WMClientClosed(var msg: TMessage);
var
    ClientNum : Integer;
    Client    : TWSocketClient;
    I         : Integer;
    //ClientGCH : GCHandle;
begin
    //ClientGCH := GCHandle(IntPtr(Msg.LParam));
    //Client    := ClientGCH.Target as TWSocketClient;
    ClientNum := Msg.LParam;
    Client    := nil;
    I := 0;
    while I < FClientList.Count do begin
        Client := FCLientList.Items[I] as TWSocketClient;
        if Client.ClientNum = ClientNum then
            break;
        Inc(I);
    end;
    // Client is not in our list ! Just ignore.
    if I >= FClientList.Count then
        Exit;

    // Remove client from list
//    FClientList.Delete(I);         //****** Notification

    try
        TriggerClientDisconnect(Client, Error);
    finally
        { Calling Destroy will automatically remove client from list because }
        { we installed a notification handler.                               }
        Client.Destroy;
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Check if a given object is one of our clients.                              }
function TCustomWSocketServer.IsClient(SomeThing : TObject) : Boolean;
begin
    if not Assigned(FClientList) then
        Result := FALSE
    else
        Result := (FClientList.IndexOf(SomeThing) >= 0);
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{*                                                                           *}
{*                            TWSocketClient                                 *}
{*                                                                           *}
{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TWSocketClient.StartConnection;
begin
    if Length(FBanner) > 0 then
        SendStr(FBanner + FLineEnd);
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Triggered when socket is closed. Need to inform server socket to update   }
{ client list and trigger client disconnect event.                          }
procedure TWSocketClient.TriggerSessionClosed(Error : Word);
begin
    if not FSessionClosedFlag then begin
        FSessionClosedFlag := TRUE;
        if Assigned(FServer) then begin
            PostMessage(FServer.Handle, WM_CLIENT_CLOSED, 0, FClientNum);
                        //Integer(IntPtr(FMyGCH))); //LongInt(Self));
        end;
        inherited TriggerSessionClosed(Error);
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This override base class GetPeerAddr. It return cached value.             }
function TWSocketClient.GetPeerAddr: String;
begin
    Result := FPeerAddr;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This override base class GetPeerPort. It return cached value.             }
function TWSocketClient.GetPeerPort: String;
begin
    Result := FPeerPort;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Override base class. Dup is called when a client is assigned to a         }
{ TWSocket. Assigning HSocket property will call Dup.                       }
procedure TWSocketClient.Dup(newHSocket : TSocket);
begin
    inherited Dup(newHSocket);
    { Cache PeerAddr value }
    FPeerAddr := inherited GetPeerAddr;
    FPeerPort := inherited GetPeerPort;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}

end.
