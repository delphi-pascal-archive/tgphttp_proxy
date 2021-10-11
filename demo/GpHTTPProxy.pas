{:Generic non-caching HTTP/1.0 and HTTPS proxy component. Uses Francois Piette's ICS suite
  (http://www.overbyte.be/). Based on the work of Wilfried Mestdagh.

  Latest version of this component can always be found at
  http://gp.17slon.com/gp/tgphttpproxy.htm.

  Thanks to: Wilfried Mestdagh, Miha Remec, Stanislav Korotky, Brian Milburn

  @author Primoz Gabrijelcic, gabr@17slon.com, http://17slon.com/gp
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

  Author             : Primoz Gabrijelcic
  Version            : 2.0
  Creation date      : 2000-03-08
  Last modification  : 2004-03-17

  </pre>}{

  Version history:
    2.0: 2004-03-17
      - Pulled in modifications from another (commercial) project to implement some fixes
        in HTTP proxy and add HTTPS proxy support.
    1.02: 2001-11-07
      - Added 'Host:' header processing.
      - Modified OnClientHeaderAvailable event to accept additional parameter -
        value of the Host: header.
        Thanks to the Stanislav Korotky for pointing out the problem.
      - Added OPTIONS request processing.
    1.01c: 2001-10-17
      - Bug fixes in next-hop-proxy handling and in username:password handling.
    1.01b: 2001-02-01
      - Fixed incompatibility between bugfix introduced in 1.01a and
        caching/blocking functionality introduced in 1.01.
    1.01a: 2001-01-30
      - Bug fixed: connection was sometimes (still) closed too early (thanks to
        Wilfried Mestdagh for the fix).
      - Bug fixed: result of TGpHTTPProxy.Listen was not always initialized.
    1.01: 2001-01-29
      - Completely rewritten OnClientHeaderAvailable event now supports caching,
        blocking, and redirecting (see info in TProxyHeaderEvent,
        TGpHTTPProxy.ProcessHeader, and demo application).
      - New event OnRemoteSocketPrepared is called from the same place as
        OnClientHeaderAvailable was called before.
      - New event OnRemoteDNSLookupDone.
      - Property TGpHTTPProxy.ClientCount is now decremented *before*
        OnClientDisconnect event handler is called.
      - Bug fixed: connection was sometimes closed too early (thanks to Miha
        Remec for the fix).
    1.0a: 2000-03-14
      - Small fix to enable app to close without calling TGpHTTPProxy.Close
        first.
    1.0: 2000-03-13
      - First release.

  What's missing:
    - A method to connect to external page cache.
    - A method to connect to external DNS cache.
    - An event to redirect data query.
}

{$IFNDEF MSWindows}{$IFDEF Win32}{$DEFINE MSWindows}{$DEFINE OldDelphi}{$ENDIF Win32}{$ENDIF MSWindows}

unit GpHTTPProxy;

interface

uses
  Windows,
  Messages,
  Forms,
  ExtCtrls,
  WinSock,
  WSocket,
  WSockets,
  SysUtils,
  Classes,
  Contnrs,
  GpIPSec,
  GpProxyData;

const
  {:Default 'HTTP proxy closed' response.}
  CHTTPClosed =
    'HTTP/1.1 403 Closed'#13#10+
    'Connection: close'#13#10+
    'Content-Type: text/html'#13#10#13#10+
    '<HTML><HEAD>'#13#10+
    '<TITLE>Closed</TITLE>'#13#10+
    '</HEAD><BODY>'#13#10+
    '<H1>Closed</H1>'#13#10+
    'HTTP proxy is closed.<P>'#13#10+
    '</BODY></HTML>'#13#10;

  {:Default 'URL blocked' response.}
  CHTTPBlocked =
    'HTTP/1.1 403 Forbidden'#13#10+
    'Connection: close'#13#10+
    'Content-Type: text/html'#13#10#13#10+
    '<HTML><HEAD>'#13#10+
    '<TITLE>Blocked</TITLE>'#13#10+
    '</HEAD><BODY>'#13#10+
    '<H1>Blocked</H1>'#13#10+
    'You are not allowed to access this URL.<P>'#13#10+
    '</BODY></HTML>'#13#10;

  {:Default 'HTTP error - Bad request' response.}
  CHTTPBadRequest =
    'HTTP/1.1 400 Bad request'#13#10+
    'Connection: close'#13#10+
    'Content-Type: text/html'#13#10#13#10+
    '<HTML><HEAD>'#13#10+
    '<TITLE>Bad request</TITLE>'#13#10+
    '</HEAD><BODY>'#13#10+
    '<H1>Bad request</H1><P>'#13#10+
    '</BODY></HTML>'#13#10;

  {:Default 'HTTP error - Forbidden IP' response.}
  CHTTPIPForbidden =
    'HTTP/1.1 403 Forbidden'#13#10+
    'Connection: close'#13#10+
    'Content-Type: text/html'#13#10#13#10+
    '<HTML><HEAD>'#13#10+
    '<TITLE>Forbidden</TITLE>'#13#10+
    '</HEAD><BODY>'#13#10+
    '<H1>Forbidden</H1>'#13#10+
    'You are not allowed to access the proxy from this IP address<P>'#13#10+
    '</BODY></HTML>'#13#10;

  {:Default 'TCP Tunnel established' response.}
  CTcpTunnelEstablished =
    'HTTP/1.0 200 Connection established'#13#10#13#10;

  {:Default 'TCP Tunnel proxy closed' response.}
  CTcpTunnelClosed =
    'HTTP/1.0 403 Closed'#13#10+
    'Connection: close'#13#10#13#10;

  {:Default 'TCP Tunnel connection blocked' response.}
  CTcpTunnelBlocked =
    'HTTP/1.0 403 Forbidden'#13#10+
    'Connection: close'#13#10#13#10;

  {:Default 'TCP Tunnel error - bad request' response.}
  CTcpTunnelBadRequest=
    'HTTP/1.0 400 Bad request'#13#10+
    'Connection: close'#13#10#13#10;

  {:Default 'TCP Tunnel connection forbidden' response.}
  CTcpTunnelIPForbidden =
    'HTTP/1.0 403 Forbidden'#13#10+
    'Connection: close'#13#10#13#10;

type
  {:All supported proxy types.
  }
  TGpProxyType = (ptHTTP, ptTCPTunnel);

  {:Set of all supported proxy types.
  }
  TGpProxyTypes = set of TGpProxyType;

  {:Configurable HTTP & TCP Tunnel proxy responses.
  }
  TGpProxyStrings = class(TPersistent)
  private
    FStrings: array [1..9] of TStrings;
  protected
    function  GetString(const Index: Integer): TStrings; virtual;
    procedure SetString(const Index: Integer; const Value: TStrings); virtual;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Assign(Source: TPersistent); override;
  published
    {:'HTTP proxy closed' response.}
    property sHTTPClosed: TStrings index 1 read GetString write SetString;
    {:'URL blocked' response.}
    property sHTTPBlocked: TStrings index 2 read GetString write SetString;
    {:'HTTP error - bad request' response.}
    property sHTTPBadRequest: TStrings index 3 read GetString write SetString;
    {:'HTTP error - IP forbidden' response.}
    property sHTTPIPForbidden: TStrings index 4 read GetString write SetString;
    {:'TCP Tunnel established' response.}
    property sTCPTunnelEstablished: TStrings index 5 read GetString write SetString;
    {:'TCP Tunnel proxy closed' response.}
    property sTCPTunnelClosed: TStrings index 6 read GetString write SetString;
    {:'TCP Tunnel connection blocked' response.}
    property sTCPTunnelBlocked: TStrings index 7 read GetString write SetString;
    {:'TCP Tunnel error - bad request' response.}
    property sTCPTunnelBadRequest: TStrings index 8 read GetString write SetString;
    {:'TCP Tunnel error - IP forbidden' response.}
    property sTCPTunnelIPForbidden: TStrings index 9 read GetString write SetString;
  end; { TGpProxyStrings }

  TGpProxyClient = class;

  {:Client socket class. Instance of this class is passed as an argument in
    various TGpHttpProxy events. To turn off the logging for that instance,
    set the Logging property to False in the event handler. This will disable
    TGpHttpProxy.OnClientDataAvailable and TGpHttpProxy.OnRemoteDataAvailable
    handler for this instance.
  }
  TGpProxyClient = class(TWSocketClient)
  private
    FAborted      : boolean;
    FCanCloseNow  : boolean;
    FGotHeader    : boolean;
    FGotRespHeader: boolean;
    FLastSendTime : int64;
    FLogging      : boolean;
    FOnDone       : TNotifyEvent;
    FPassword     : string;
    FPeerAddrLong : u_long;
    FProxyType    : TGpProxyType;
    FRcvd         : string;
    FRemoteContent: string;
    FRemoteRcvd   : string;
    FRemoteSocket : TWSocket;
    FSendBuffer   : string;
    FUsername     : string;
    FUsingNextHop : boolean;
  protected
    procedure CreateRemoteSocket; virtual;
    procedure DestroyRemoteSocket; virtual;
    procedure DoDataSent(sender: TObject; error: word); virtual;
    procedure DoSessionClosed(sender: TObject; error: word); virtual;
    procedure Kill;
    procedure SetProxyType(proxyType: TGpProxyType); virtual;
    procedure Stop(errorCode: integer);
    procedure Stop2;
    procedure TriggerDataSent(error: word); override;
    function  TrySendFromBuffer: integer; virtual;
  {properties}
    {:Indicates that socket is shutting down.}
    property Aborted: boolean read FAborted;
    {:Indicates whether socket should be closed when all data will be sent.}
    property CanCloseNow: boolean read FCanCloseNow write FCanCloseNow;
    {:True when HTTP header was completely received.}
    property GotHeader: boolean read FGotHeader write FGotHeader;
    {:True when TCP Tunnel response from the remote machine was received.}
    property GotResponseHeader: boolean read FGotRespHeader write FGotRespHeader;
    {:Time (ticks) when last data was sent to the client.}
    property LastSendTime: int64 read FLastSendTime write FLastSendTime;
    {:Password for the remote site.}
    property Password: string read FPassword write FPassword;
    {:PeerAddr converted to u_long.}
    property PeerAddrLong: u_long read FPeerAddrLong write FPeerAddrLong;
    {:Received (but not yet processed) data.}
    property Received: string read FRcvd write FRcvd;
    {:Fake content that should be returned instead of the true content (HTTP proxy).}
    property RemoteContent: string read FRemoteContent write FRemoteContent;
    {:Received from the remote.}
    property RemoteReceived: string read FRemoteRcvd write FRemoteRcvd;
    {:Username for the remote site.}
    property Username: string read FUsername write FUsername;
    {:True if next-hop proxy is used.}
    property UsingNextHop: boolean read FUsingNextHop write FUsingNextHop;
    {:Triggered when client has terminated.}
    property OnDone: TNotifyEvent read FOnDone write FOnDone;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    function  SendStr(const data: string): integer; override;
  {properties}
    {:Set to False to disable logging of this client socket.}
    property Logging: boolean read FLogging write FLogging default true;
    {:Type of this connection - HTTP proxy or TCP Tunnel proxy.}
    property ProxyType: TGpProxyType read FProxyType;
    {:Remote socket this client socket is connected to.}
    property RemoteSocket: TWSocket read FRemoteSocket;
  end; { TGpProxyClient }

  {:TGpProxyClient class reference type.
  }
  TGpProxyClientClass = class of TGpProxyClient;

  {:Generic proxy event - on connect, on disconnect...
    @param   Sender Instance of TGpGenericProxy that generated the event.
    @param   Client Client socket.
  }
  TGpProxyEvent = procedure(sender: TObject; Client: TGpProxyClient) of object;

  {:Data Available event.
    @param   Sender Instance of TGpGenericProxy that generated the event.
    @param   Client Client socket.
    @param   data Received data.
  }
  TGpProxyReceiveEvent = procedure(sender: TObject; Client: TGpProxyClient;
    data: string) of object;

  {:Header available event. Triggered after the header is received but before
    connection to remote is established. Application can at that point modify
    the target url, force next hop proxy to be ignored, or return appropriate
    HTTP response.
    @param   Sender  Instance of TGpHttpProxy that generated the event.
    @param   Client  Client socket.
    @param   url     Requested URL.
    @param   header  HTTP request header. May be modified in event handler.
    @param   proto   Protocol part of URL. May be modified in event handler.
    @param   user    User part of URL. May be modified in event handler.
    @param   pass    Password part of URL. May be modified in event handler.
    @param   host    Host part of URL. May be modified in event handler.
    @param   path    Path part of URL. May be modified in event handler.
    @param   hdrHost Contents of the Host: HTTP header line. May be modified in
                     event handler.
    @param   ignoreNextHopProxy False when event handler is called. If set to
                    true in event handler, next hop proxy will be ignored for
                    this request.
    @param   returnContent Empty when event handler is called. If set to some
                    value, no connection will be established and contents of
                    'returnContent' will be returned to the client socket. Use
                    to implement caching or blocking. If set, next hop proxy
                    will be ignored regardless of 'ignoreNextHopProxy' flag.
  }
  TGpProxyHeaderEvent = procedure(sender: TObject; Client: TGpProxyClient;
    url: string; var header, proto, user, pass, host, port, path, hdrHost: string;
    var ignoreNextHopProxy: boolean; var returnContent: string) of object;

  {:Tunnel requested event. Triggered after the tunnel request header is
    received but before the connection to remote host is established.
    Application can at that point modify the target address and port, force next
    hop proxy to be ignored, or return appropriate response.
    @param   Sender Instance of TGpHttpProxy that generated the event.
    @param   Client Client socket.
    @param   host   Remote address. May be modified in event handler.
    @param   port   Remote port. May be modified in event handler.
    @param   ignoreNextHopProxy False when event handler is called. If set to
                    true in event handler, next hop proxy will be ignored for
                    this request.
    @param   returnContent Empty when event handler is called. If set to some
                    value, no connection will be established and contents of
                    'returnContent' will be returned to the client socket. Use
                    to implement caching or blocking. If set, next hop proxy
                    will be ignored regardless of 'ignoreNextHopProxy' flag.
  }
  TGpProxyTunnelRequestEvent = procedure(sender: TObject;
    Client: TGpProxyClient; var host, port: string;
    var ignoreNextHopProxy: boolean; var returnContent: string) of object;

  {:Debug log event
    @since   2003-09-21
  }
  TGpProxyDebugLogEvent = procedure(sender: TObject;
    const logMessage: string) of object;

  {:Server closed event.
    @since   2004-01-08
  }
  TGpProxyServerClosedEvent = procedure(sender: TObject; error: word) of object;

  {:Remote connection connected (or connection failed) event.
    @since   2004-03-14
  }
  TGpProxyRemoteConnectEvent = procedure(sender: TObject;
    socket: TGpProxyClient) of object;

  {:Remote connection disconnected (or disconnection failed) event.
    @since   2004-03-14
  }
  TGpProxyRemoteDisconnectEvent = procedure(sender: TObject;
    socket: TGpProxyClient) of object;

  {:Abstract class for all proxy components.
  }
  TGpGenericProxy = class(TComponent)
  private
    FActive                : boolean;
    FAllowedIP             : TStrings;
    FClientCount           : integer;
    FIPSec                 : TGpIPSec;
    FLocalAddress          : string;
    FOnClientConnect       : TGpProxyEvent;
    FOnClientDataAvailable : TGpProxyReceiveEvent;
    FOnClientDisconnect    : TGpProxyEvent;
    FOnDebugLog            : TGpProxyDebugLogEvent;
    FOnRemoteConnect       : TGpProxyRemoteConnectEvent;
    FOnRemoteDataAvailable : TGpProxyReceiveEvent;
    FOnRemoteDisconnect    : TGpProxyRemoteDisconnectEvent;
    FOnRemoteDNSLookupDone : TGpProxyEvent;
    FOnRemoteSocketPrepared: TGpProxyEvent;
    FOnServerClosed        : TGpProxyServerClosedEvent;
    FOnServerListening     : TNotifyEvent;
    FPort                  : integer;
    FWSocketServer         : TWSocketServer;
  protected
    procedure AllowedIPChanged(sender: TObject); virtual;
    procedure BgException(sender: TObject; E: Exception; var CanClose: Boolean); virtual;
    procedure CloseSocketServer; virtual;
    procedure DoClientConnect(Client: TGpProxyClient); virtual;
    procedure DoClientDataAvailable(Client: TGpProxyClient; data: string); virtual;
    procedure DoClientDisconnect(Client: TGpProxyClient); virtual;
    procedure DoOnDebugLog(const logMessage: string); virtual;
    procedure DoRemoteConnect(Client: TGpProxyClient); virtual;
    procedure DoRemoteDataAvailable(Client: TGpProxyClient; data: string); virtual;
    procedure DoRemoteDisconnect(Client: TGpProxyClient); virtual;
    procedure DoRemoteDNSLookupDone(Client: TGpProxyClient); virtual;
    procedure DoRemoteSocketPrepared(Client: TGpProxyClient); virtual;
    procedure DoServerClosed(error: word); virtual;
    procedure DoServerListening; virtual;
    function  GetClientClass: TGpProxyClientClass; virtual;
    procedure HookRemoteEvents(RemoteSocket: TWSocket); virtual;
    procedure InternalClose(Client: TGpProxyClient); virtual;
    function  OpenSocketServer: string; virtual;
    procedure ProxyClientDataAvailable(sender: TObject; error: word); virtual;
    procedure RemoteDnsLookupDone(sender: TObject; error: word); virtual;
    procedure RemoteSessionClosed(sender: TObject; error: word); virtual;
    procedure SendText(socket: TWSocket; data: string); virtual;
    procedure SetAllowedIP(const Value: TStrings); virtual;
    procedure SetClientClass(const Value: TGpProxyClientClass); virtual;
    procedure SetLocalAddress(const Value: string); virtual;
    procedure SetPort(const Value: integer); virtual;
    procedure WSocketServerClientConnect(sender: TObject; Client: TWSocketClient; error: word); virtual;
    procedure WSocketServerClientCreate(sender: TObject; Client: TWSocketClient); virtual;
    procedure WSocketServerClientDisconnect(sender: TObject; Client: TWSocketClient; error: word); virtual;
    procedure WSocketServerSessionClosed(sender: TObject; error: word); virtual;
//    procedure WSocketServerSessionConnected(sender: TObject; error: word); virtual;
  {abstract}
    procedure ReceivedFromClient(Client: TGpProxyClient; clientData: string); virtual; abstract;
    procedure RemoteDataAvailable(sender: TObject; error: word); virtual; abstract;
    procedure RemoteSessionConnected(sender: TObject; error: word); virtual; abstract;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    procedure Close; virtual;
    function  Listen: string; virtual;
  {properties}
    {:True if proxy is listening.}
    property Active: boolean read FActive;
    {:TGpProxyClient derived class to instantiate for each client. Can be
      set only when proxy is not Active.}
    property ClientClass: TGpProxyClientClass read GetClientClass write SetClientClass;
    {:Access to underlying TWSocketServer.}
    property SocketServer: TWSocketServer read FWSocketServer;
  {published}
    {:List of the IP addresses allowed to access the proxy. Each line should
      contain:
      - string 'localhost' (macro for all server IP addresses)
      - host name 'my.host.com'
      - IP address 'xxx.yyy.www.zzz'
      - IP address + mask 'xxx.yyy.www.zzz/nnn.nnn.nnn.nnn'}
    property AllowedIP: TStrings read FAllowedIP write SetAllowedIP;
    {:Number of connected clients.}
    property ClientCount: integer read FClientCount;
    {:Local address. Default = '' meaning 'bind to anything'.}
    property LocalAddress: string read FLocalAddress write SetLocalAddress;
    {:Listening port. Can be set only when proxy is not Active.}
    property Port: integer read FPort write SetPort;
  {events}
    {:Triggered when client connects to proxy. Set Client socket parameters here.}
    property OnClientConnect: TGpProxyEvent
      read FOnClientConnect write FOnClientConnect;
    {:Triggered when proxy receives data from client.}
    property OnClientDataAvailable: TGpProxyReceiveEvent
      read FOnClientDataAvailable write FOnClientDataAvailable;
    {:Triggered when client disconnects from proxy.}
    property OnClientDisconnect: TGpProxyEvent
      read FOnClientDisconnect write FOnClientDisconnect;
    {:Triggered when remote connects to proxy.}
    property OnRemoteConnect: TGpProxyRemoteConnectEvent
      read FOnRemoteConnect write FOnRemoteConnect;
    {:Triggered when proxy receives data from remote.}
    property OnRemoteDataAvailable: TGpProxyReceiveEvent
      read FOnRemoteDataAvailable write FOnRemoteDataAvailable;
    {:Triggered when remote disconnects from proxy.}
    property OnRemoteDisconnect: TGpProxyRemoteDisconnectEvent
      read FOnRemoteDisconnect write FOnRemoteDisconnect;
    {:Triggered when DNS lookup on remote address is done.}
    property OnRemoteDNSLookupDone: TGpProxyEvent
      read FOnRemoteDNSLookupDone write FOnRemoteDNSLookupDone;
    {:Triggered when remote socket is created but before it is connected. Event
      handler can modify properties for Client.RemoteSocket at this point.}
    property OnRemoteSocketPrepared: TGpProxyEvent
      read FOnRemoteSocketPrepared write FOnRemoteSocketPrepared;
    {:Triggered when server stops listening.}
    property OnServerClosed: TGpProxyServerClosedEvent
      read FOnServerClosed write FOnServerClosed;
    {:Triggered when server starts listening.}
    property OnServerListening: TNotifyEvent
      read FOnServerListening write FOnServerListening;
  published
    //:Debug log.
    property OnDebugLog: TGpProxyDebugLogEvent
      read FOnDebugLog write FOnDebugLog;
  end; { TGpGenericProxy }

  {:Non-caching proxy component supporting HTTP connections and TCP Tunneling.
  }
  TGpHttpProxy = class(TGpGenericProxy)
  private
    FEnabledTypes           : TGpProxyTypes;
    FNextHopProxy           : array [ptHTTP..ptTCPTunnel] of TGpProxyData;
    FOnClientHeaderAvailable: TGpProxyHeaderEvent;
    FOnTunnelRequest        : TGpProxyTunnelRequestEvent;
    FResponse               : TGpProxyStrings;
  protected
    procedure DoClientHeaderAvailable(Client: TGpProxyClient; url: string;
      var header, proto, user, pass, host, port, path, hdrHost: string;
      var ignoreNextHopProxy: boolean; var returnContent: string); virtual;
    procedure DoTunnelRequest(Client: TGpProxyClient; var ahost,
      aport: string; var ignoreNextHopProxy: boolean; var returnContent: string);
    function  ExtractHeader(header, headerTag: string): string;
    function  GetNextHopProxy(index: TGpProxyType): TGpProxyData;
    procedure ProcessHeader(Client: TGpProxyClient); virtual;
    function  ProcessHTTPHeader(Client: TGpProxyClient;
      var header, ahost, aport, returnContent: string): boolean;
    function  ProcessTCPTunnelHeader(Client: TGpProxyClient;
      var header, ahost, aport, returnContent: string): boolean; virtual;
    procedure ReplaceHeader(var header: string; headerTag,
      newValue: string);
    procedure SetNextHopProxy(index: TGpProxyType; const Value: TGpProxyData); virtual;
    procedure SetResponse(const Value: TGpProxyStrings); virtual;
  {override}
    procedure ReceivedFromClient(Client: TGpProxyClient; clientData: string); override;
    procedure RemoteDataAvailable(sender: TObject; error: word); override;
    procedure RemoteSessionConnected(sender: TObject; error: word); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
  published
    property AllowedIP;
    property LocalAddress;
    property Port;
    property OnClientConnect;
    property OnClientDataAvailable;
    property OnClientDisconnect;
    property OnRemoteConnect;
    property OnRemoteDataAvailable;
    property OnRemoteDisconnect;
    property OnRemoteDNSLookupDone;
    property OnRemoteSocketPrepared;
    property OnServerClosed;
    property OnServerListening;
  {introduced}
    {:Enabled proxy types. HTTP and TCP Tunnel are enabled by default.}
    property EnabledTypes: TGpProxyTypes
      read FEnabledTypes write FEnabledTypes default [ptHTTP..ptTCPTunnel];
    {:Next hop HTTP proxy. If you want to connect directly to internet, set
      Address subproperty to ''.}
    property NextHopHTTP: TGpProxyData index ptHTTP
      read GetNextHopProxy write SetNextHopProxy;
    {:Next hop TCP Tunneling proxy. If you want to connect directly to internet,
      set Address subproperty to ''.}
    property NextHopTCPTunnel: TGpProxyData index ptTCPTunnel
      read GetNextHopProxy write SetNextHopProxy;
    {:Configurable response strings.}
    property Response: TGpProxyStrings read FResponse write SetResponse;
  {events}
    {:Triggered when complete header is available. Set Client.RemoteSocket
      parameters here. Use HTTPProt.ParseURL to split url into parts.}
    property OnClientHeaderAvailable: TGpProxyHeaderEvent
      read FOnClientHeaderAvailable write FOnClientHeaderAvailable;
    {:Triggered when tunnel request header is received.}
    property OnTunnelRequest: TGpProxyTunnelRequestEvent
      read FOnTunnelRequest write FOnTunnelRequest;
  end; { TGpHttpProxy }

procedure Register;

implementation

uses
  {$IFNDEF OldDelphi}
  {$WARN UNIT_PLATFORM OFF}
  {$ENDIF OldDelphi}
  FileCtrl,
  HTTPProt,
  GpString;

const
  //:CR/LF pair.
  CRLF = #13#10;
  //:Two CR/LF sequences in a row.
  CRLFCRLF = CRLF+CRLF;
  //:.CRLF - message terminator.
  DotCRLF = '.'#13#10;

type
  TStringListFriend = class(TStringList);

{ globals }

procedure Register;
begin
  RegisterComponents('FPiette', [TGpHttpProxy]);
end; { Register }

{:Missing parts of Windows' ICS.
}
function Posn(const s, t: string; count: integer): integer;
var
  i, h, Last: integer;
  u         : string;
begin
  u := t;
  if count > 0 then begin
    Result := Length(t);
    for i := 1 to count do begin
      h := Pos(s, u);
      if h > 0 then
        u := Copy(u, h + 1, Length(u))
      else begin
        u := '';
        Inc(Result);
      end;
    end;
    Result := Result - Length(u);
  end
  else if count < 0 then begin
    Last := 0;
    for i := Length(t) downto 1 do begin
      u := Copy(t, i, Length(t));
      h := Pos(s, u);
      if (h <> 0) and ((h + i) <> Last) then begin
        Last := h + i - 1;
        Inc(count);
        if count = 0 then
          break; //for i
      end;
    end;
    if count = 0 then
      Result := Last
    else
      Result := 0;
  end
  else
    Result := 0;
end; { Posn }

procedure ParseURL(const url: string; var Proto, User, Pass, Host, Port,
  Path: string);
var
  p, q   : integer;
  s      : string;
  CurPath: string;
begin
  CurPath := Path;
  proto   := '';
  User    := '';
  Pass    := '';
  Host    := '';
  Port    := '';
  Path    := '';
  if Length(url) < 1 then
      Exit;
  { Handle path beginning with "./" or "../".          }
  { This code handle only simple cases !               }
  { Handle path relative to current document directory }
  if (Copy(url, 1, 2) = './') then begin
    p := Posn('/', CurPath, -1);
    if p > Length(CurPath) then
      p := 0;
    if p = 0 then
      CurPath := '/'
    else
      CurPath := Copy(CurPath, 1, p);
    Path := CurPath + Copy(url, 3, Length(url));
    Exit;
  end
  { Handle path relative to current document parent directory }
  else if (Copy(url, 1, 3) = '../') then begin
    p := Posn('/', CurPath, -1);
    if p > Length(CurPath) then
      p := 0;
    if p = 0 then
      CurPath := '/'
    else
      CurPath := Copy(CurPath, 1, p);
    s := Copy(url, 4, Length(url));
    { We could have several levels }
    while true do begin
      CurPath := Copy(CurPath, 1, p-1);
      p := Posn('/', CurPath, -1);
      if p > Length(CurPath) then
        p := 0;
      if p = 0 then
        CurPath := '/'
      else
        CurPath := Copy(CurPath, 1, p);
      if (Copy(s, 1, 3) <> '../') then
        break; // while
      s := Copy(s, 4, Length(s));
    end; //while
    Path := CurPath + Copy(s, 1, Length(s));
    Exit;
  end;
  p := Pos('://',url);
  if p = 0 then begin
    if (url[1] = '/') then begin
      { Relative path without protocol specified }
      proto := 'http';
      p     := 1;
      if (Length(url) > 1) and (url[2] <> '/') then begin
        { Relative path }
        Path := Copy(url, 1, Length(url));
        Exit;
      end;
    end
    else if lowercase(Copy(url, 1, 5)) = 'http:' then begin
      proto := 'http';
      p     := 6;
      if (Length(url) > 6) and (url[7] <> '/') then begin
        { Relative path }
        Path := Copy(url, 6, Length(url));
        Exit;
      end;
    end
    else if lowercase(Copy(url, 1, 7)) = 'mailto:' then begin
      proto := 'mailto';
      p := pos(':', url);
    end;
  end
  else begin
    proto := Copy(url, 1, p - 1);
    inc(p, 2);
  end;
  s := Copy(url, p + 1, Length(url));
  p := Pos('/', s);
  q := Pos('?', s);
  if (q > 0) and ((q < p) or (p = 0)) then
    p := q;
  if p = 0 then
    p := Length(s) + 1;
  Path := Copy(s, p, Length(s));
  s    := Copy(s, 1, p-1);
  p := Posn(':', s, -1);
  if p > Length(s) then
    p := 0;
  q := Posn('@', s, -1);
  if q > Length(s) then
    q := 0;
  if (p = 0) and (q = 0) then begin   { no user, password or port }
    Host := s;
    Exit;
  end
  else if q < p then begin  { a port given }
    Port := Copy(s, p + 1, Length(s));
    Host := Copy(s, q + 1, p - q - 1);
    if q = 0 then
      Exit; { no user, password }
    s := Copy(s, 1, q - 1);
  end
  else begin
    Host := Copy(s, q + 1, Length(s));
    s := Copy(s, 1, q - 1);
  end;
  p := Pos(':', s);
  if p = 0 then
    User := s
  else begin
    User := Copy(s, 1, p - 1);
    Pass := Copy(s, p + 1, Length(s));
  end;
end; { ParseURL }

{:Remove one line from the input.
  @param   list Multiline input.
  @param   line (out) First line of the input.
  @returns Input without the first line.
}
function GetLineFrom(const list: string; var line: string): string;
var
  p: integer;
begin
  p := Pos(CRLF,list);
  if p > 0 then begin
    line := First(list,p-1);
    Result := list;
    Delete(Result,1,p+1);
  end
  else
    line := '';
end; { GetLineFrom }

{:Get first line from the multiline string.
  @param   list Multiline string.
  @returns First line of the multiline string.
}
function GetFirstLine(const list: string): string;
var
  p: integer;
begin
  p := Pos(CRLF,list);
  if p > 0 then
    Result := First(list,p-1)
  else
    Result :=  '';
end; { GetFirstLine }

{$IFDEF OldDelphi}
function IncludeTrailingPathDelimiter(const path: string): string;
begin
  Result := IncludeTrailingBackslash(path);
end; { IncludeTrailingPathDelimiter }
{$ENDIF OldDelphi}

{:Check if specified amount of time has elapsed.
  @param   start   Start of timed period.
  @param   timeout Timeout value in milliseconds.
  @returns True if more than timeout milliseconds has elapsed since start.
}
function Elapsed(start: int64; timeout: DWORD): boolean;
var
  stop: int64;
begin
  if timeout = 0 then
    Result := true
  else begin
    stop := GetTickCount;
    {$IFNDEF Linux}
    if stop < start then
      stop := stop + $100000000;
    {$ENDIF}
    Result := ((stop-start) > timeout);
  end;
end; { Elapsed }

function NoCRLF(const s: string): string;
begin
  if Last(s, 2) = CRLF then
    Result := ButLast(s, 2)
  else
    Result := s;
end; { NoCRLF }

{:Return address in <quoted> form.
  @since   2003-05-11
}        
function Quote(const addr: string): string;
begin
  if First(TrimL(addr), 1) = '<' then
    Result := addr
  else
    Result := '<' + addr + '>';
end; { Quote }

{:Unquote quoted part of the address and return it.
  @since   2003-05-11
}
function Unquote(const addr: string): string;
var
  p: integer;
begin
  Result := addr;
  p := Pos('<', Result);
  if p > 0 then begin
    Delete(Result, 1, p);
    p := Pos('>', Result);
    if p > 0 then
      Result := Copy(result, 1, p-1);
  end
  else if (Length(Result) > 0) and (Result[Length(Result)] = '>') then
    Delete(Result, Length(Result), 1);
end; { Unquote }

{ TGpProxyClient }

{:Create client socket object. Enable logging by default.
}
constructor TGpProxyClient.Create;
begin
  inherited Create(AOwner);
  Server := AOwner as TCustomWSocketServer;
  FLogging := true;
  ComponentOptions := ComponentOptions + [wsoNoReceiveLoop];
  OnDataSent := DoDataSent;
  OnSessionClosed := DoSessionClosed;
end; { TGpProxyClient.Create }

{:Create remote socket.
}
procedure TGpProxyClient.CreateRemoteSocket;
begin
  FRemoteSocket := TWSocket.Create(self);
end; { TGpProxyClient.CreateRemoteSocket }

{:Destroy client socket object. Free remote socket object first.
}
destructor TGpProxyClient.Destroy;
begin
  try
    DestroyRemoteSocket;
    inherited;
  except end; // could cause some weird problems when socket's Create fails
end; { TGpProxyClient.Destroy }

{:Destroy remote socket.
}
procedure TGpProxyClient.DestroyRemoteSocket;
begin
  FreeAndNil(FRemoteSocket);
end; { TGpProxyClient.DestroyRemoteSocket }

{:Handle own OnDataSent to implement buffered send.
}
procedure TGpProxyClient.DoDataSent(sender: TObject; error: word);
begin
  TrySendFromBuffer;
end; { TGpProxyClient.DoDataSent }

procedure TGpProxyClient.DoSessionClosed(sender: TObject; error: word);
begin
  if Error <> 0 then
    Stop(error)
  else
    Stop2;
end; { TGpProxyClient.DoSessionClosed }

procedure TGpProxyClient.Kill;
begin
  FAborted := true;
  if FPaused then
    Resume;
  Stop(-1);
end; { TGpProxyClient.Kill }

function TGpProxyClient.SendStr(const data: string): integer;
begin
  Result := inherited SendStr(data);
  LastSendTime := GetTickCount;
end; { TGpProxyClient.SendStr }

{:Set type of proxying done for this client.
}
procedure TGpProxyClient.SetProxyType(proxyType: TGpProxyType);
begin
  FProxyType := proxyType;
end; { TGpProxyClient.SetProxyType }

procedure TGpProxyClient.Stop(errorCode: integer);
begin
  OnDataSent := nil;
  if State in [wsInvalidState, wsClosed] then
    Stop2
  else
    CloseDelayed;
end; { TGpProxyClient.Stop }

procedure TGpProxyClient.Stop2;
begin
  OnSessionClosed := nil;
  if assigned(FOnDone) then
    FOnDone(Self);
end; { TGpProxyClient.Stop2 }

{:Data was sent to the remote socket. Check if socket must shutdown.
}
procedure TGpProxyClient.TriggerDataSent(error: word);
begin
  inherited;
  if FCanCloseNow then
    ShutDown(1);
end; { TGpProxyClient.TriggerDataSent }

{:Try to send one line from the buffer.
  @returns Number of bytes sent.
}
function TGpProxyClient.TrySendFromBuffer: integer;
begin
  Result := Pos(CRLF,FSendBuffer);
  if Result > 0 then begin
    Result := inherited SendStr(First(FSendBuffer,Result+1));
    LastSendTime := GetTickCount;
    Delete(FSendBuffer,1,Result);
  end;
end; { TGpProxyClient.TrySendFromBuffer }

{ TGpProxyStrings }

procedure TGpProxyStrings.Assign(Source: TPersistent);
var
  iString: integer;
begin
  if Source is TGpProxyStrings then
    for iString := Low(FStrings) to High(FStrings) do
      FStrings[iString].Assign(TGpProxyStrings(Source).GetString(iString))
  else
    inherited;
end; { TGpProxyStrings.Assign }

constructor TGpProxyStrings.Create;
const
  CInitStrings: array [Low(FStrings)..High(FStrings)] of string =
    (CHTTPClosed, CHTTPBlocked, CHTTPBadRequest, CHTTPIPForbidden,
     CTcpTunnelEstablished, CTcpTunnelClosed, CTcpTunnelBlocked,
     CTcpTunnelBadRequest,CTcpTunnelIPForbidden);
var
  iString: integer;
begin
  for iString := Low(FStrings) to High(FStrings) do begin
    FStrings[iString] := TStringList.Create;
    FStrings[iString].Text := CInitStrings[iString];
  end; //for
end; { TGpProxyStrings.Create }

destructor TGpProxyStrings.Destroy;
var
  iString: integer;
begin
  for iString := Low(FStrings) to High(FStrings) do
    FreeAndNil(FStrings[iString]);
  inherited;
end; { TGpProxyStrings.Destroy }

function TGpProxyStrings.GetString(const Index: Integer): TStrings;
begin
  Result := FStrings[Index];
end; { TGpProxyStrings.GetString }

procedure TGpProxyStrings.SetString(const Index: Integer;
  const Value: TStrings);
begin
  FStrings[Index].Assign(Value);
end; { TGpProxyStrings.SetString }

{ TGpGenericProxy }

{:Triggered when AllowedIP property changes.
}
procedure TGpGenericProxy.AllowedIPChanged(sender: TObject);
begin
  FIPSec.AllowedIP := FAllowedIP;
  // Change AllowedIP property without triggering AllowedIPChanged event.
  TStringList(FAllowedIP).OnChange := nil;
  FAllowedIP.Assign(FIPSec.AllowedIP);
  TStringList(FAllowedIP).OnChange := AllowedIPChanged;
end; { TGpGenericProxy.AllowedIPChanged }

{:Socket background exception handler. Forwards exceptions to the OnBgException
  event.
}
procedure TGpGenericProxy.BgException(sender: TObject; E: Exception;
  var CanClose: Boolean);
begin
  try
    CanClose := false; // don't terminate the server!
    DoOnDebugLog(Format('Background exception in server: %s', [E.Message]));
  except end; // it is not a good idea to crash inside the background exception handler
end; { TGpGenericProxy.BgException }

{:Close proxy object.
}
procedure TGpGenericProxy.Close;
begin
  DoOnDebugLog('TGpGenericProxy.Close');
  CloseSocketServer;
  FActive := false;
end; { TGpGenericProxy.Close }

{:Close all open sockets.
}
procedure TGpGenericProxy.CloseSocketServer;
var
  i: integer;
begin
  DoOnDebugLog('TGpGenericProxy.CloseSocketServer');
  for i := 0 to FWSocketServer.ClientCount - 1 do
    if assigned(FWSocketServer.Client[i]) then
      FWSocketServer.Client[i].Close;
  if not (csDestroying in ComponentState) then
    FWSocketServer.Close;
end; { TGpGenericProxy.CloseSocketServer }

{:Create proxy object.
}
constructor TGpGenericProxy.Create(AOwner: TComponent);
begin
  inherited;
  FWSocketServer := TWSocketServer.Create(nil);
  with FWSocketServer do begin
    Addr                := '0.0.0.0';
    Banner              := '';
    BannerTooBusy       := '';
    ClientClass         := TGpProxyClient;
    FlushTimeout        := 60;
    LineEcho            := false;
    LineEdit            := false;
    LineMode            := false;
    LingerOnOff         := wsLingerOn;
    LingerTimeout       := 0;
    LocalAddr           := '0.0.0.0';
    LocalPort           := '0';
    MaxClients          := 0;
    MultiThreaded       := false;
    Proto               := 'tcp';
    SendFlags           := wsSendNormal;
    SocksAuthentication := socksNoAuthentication;
    SocksLevel          := '5';
    OnBgException       := BgException;
    OnClientConnect     := WSocketServerClientConnect;
    OnClientCreate      := WSocketServerClientCreate;
    OnClientDisconnect  := WSocketServerClientDisconnect;
    OnSessionClosed     := WSocketServerSessionClosed;
//    OnSessionConnected  := WSocketServerSessionConnected;
  end;
  FIPSec := TGPIPSec.Create;
  FAllowedIP := TStringList.Create;
  TStringList(FAllowedIP).OnChange := AllowedIPChanged;
end; { TGpGenericProxy.Create }

{:Destroy socket object.
}
destructor TGpGenericProxy.Destroy;
begin
  DoOnDebugLog('TGpGenericProxy.Destroy');
  CloseSocketServer;
  FreeAndNil(FAllowedIP);
  FreeAndNil(FIPSec);
  FreeAndNil(FWSocketServer);
  inherited;
end; { TGpGenericProxy.Destroy }

{:OnClientConnect forwarder.
}
procedure TGpGenericProxy.DoClientConnect(Client: TGpProxyClient);
begin
  if assigned(FOnClientConnect) then
    FOnClientConnect(self,Client);
end; { TGpGenericProxy.DoClientConnect }

{:OnClientDataAvailable forwarder.
}
procedure TGpGenericProxy.DoClientDataAvailable(Client: TGpProxyClient;
  data: string);
begin
  if assigned(FOnClientDataAvailable) and Client.Logging then
    FOnClientDataAvailable(self,Client,data);
end; { TGpGenericProxy.DoClientDataAvailable }

{:OnClientDisconnect forwarder.
}
procedure TGpGenericProxy.DoClientDisconnect(Client: TGpProxyClient);
begin
  if assigned(FOnClientDisconnect) then
    FOnClientDisconnect(self,Client);
end; { TGpGenericProxy.DoClientDisconnect }

procedure TGpGenericProxy.DoOnDebugLog(const logMessage: string);
begin
  if assigned(FOnDebugLog) then
    FOnDebugLog(Self, logMessage);
end; { TGpGenericProxy.DoOnDebugLog }

{:OnRemoteConnect forwarder.
}
procedure TGpGenericProxy.DoRemoteConnect(client: TGpProxyClient);
begin
  if assigned(FOnRemoteConnect) then
    FOnRemoteConnect(self, client);
end; { TGpGenericProxy.DoRemoteConnect }

{:OnRemoteDataAvailable forwarder.
}
procedure TGpGenericProxy.DoRemoteDataAvailable(Client: TGpProxyClient;
  data: string);
begin
  if assigned(FOnRemoteDataAvailable) and Client.Logging then
    FOnRemoteDataAvailable(self, Client, data);
end; { TGpGenericProxy.DoRemoteDataAvailable }

{:OnRemoteDisconnect forwarder.
}
procedure TGpGenericProxy.DoRemoteDisconnect(client: TGpProxyClient);
begin
  if assigned(FOnRemoteDisconnect) then
    FOnRemoteDisconnect(self, client);
end; { TGpGenericProxy.DoRemoteDisconnect }

{:OnRemoteDNSLookupDone forwarder.
}
procedure TGpGenericProxy.DoRemoteDNSLookupDone(Client: TGpProxyClient);
begin
  if assigned(FOnRemoteDNSLookupDone) then
    FOnRemoteDNSLookupDone(self,Client);
end; { TGpGenericProxy.DoRemoteDNSLookupDone }

{:OnRemoteSocketPrepared forwarder.
}
procedure TGpGenericProxy.DoRemoteSocketPrepared(Client: TGpProxyClient);
begin
  if assigned(FOnRemoteSocketPrepared) then
    FOnRemoteSocketPrepared(self,Client);
end; { TGpGenericProxy.DoRemoteSocketPrepared }

{:OnServerClosed forwarder.
}
procedure TGpGenericProxy.DoServerClosed(error: word);
begin
  if assigned(FOnServerClosed) then
    FOnServerClosed(self, error);
end; { TGpGenericProxy.DoServerClosed }

{:OnServerListening forwarder.
}
procedure TGpGenericProxy.DoServerListening;
begin
  if assigned(FOnServerListening) then
    FOnServerListening(self);
end; { TGpGenericProxy.DoServerListening }

{:Return class of the client sockets.
}
function TGpGenericProxy.GetClientClass: TGpProxyClientClass;
begin
  Result := TGpProxyClientClass(FWSocketServer.ClientClass);
end; { TGpGenericProxy.GetClientClass }

{:Hook various events for the remote socket object.
}
procedure TGpGenericProxy.HookRemoteEvents(RemoteSocket: TWSocket);
begin
  RemoteSocket.OnSessionConnected := {abstract}RemoteSessionConnected;
  RemoteSocket.OnDataAvailable    := {abstract}RemoteDataAvailable;
  RemoteSocket.OnSessionClosed    := RemoteSessionClosed;
  RemoteSocket.OnBgException      := BgException;
  RemoteSocket.OnDnsLookupDone    := RemoteDnsLookupDone;
end; { TGpGenericProxy.HookRemoteEvents }

{:Close client socket.
}
procedure TGpGenericProxy.InternalClose(Client: TGpProxyClient);
begin
  with Client do begin
    if bAllSent then
      ShutDown(1)
    else
      CanCloseNow := true;
  end; //with
end; { TGpGenericProxy.InternalClose }

{:Start listening on the specified port.
  @returns Exception message if port is already in use.
}
function TGpGenericProxy.Listen: string;
begin
  Result := '';
  if not FActive then begin
    try
      FWSocketServer.Port  := IntToStr(FPort);
      if FLocalAddress = '' then
        FWSocketServer.Addr  := '0.0.0.0'
      else
        FWSocketServer.Addr := FLocalAddress;
      FWSocketServer.Proto := 'tcp';
      FWSocketServer.Listen;
      Result := OpenSocketServer;
      if Result <> '' then begin
        DoOnDebugLog(Format('Listen failed (%s), will close', [Result]));
        Close;
      end
      else begin
        FActive := true;
        DoServerListening;
      end;
    except
      on E:ESocketException do begin
        Result := E.Message;
      end;
    end;
  end;
end; { TGpGenericProxy.Listen }

{:Called after socket server went into 'listen' mode but after the status is
  returned to the caller. Derived classes can override this function to add
  server initialization code. Overridden function should return error message
  or '' for 'no error'.
  @since   2002-12-18
}        
function TGpGenericProxy.OpenSocketServer: string;
begin
  Result := '';
end; { TGpGenericProxy.OpenSocketServer }

{:Handler for the client socket's OnDataAvailable event. Process received data.
}
procedure TGpGenericProxy.ProxyClientDataAvailable(sender: TObject; error: word);
var
  Client    : TGpProxyClient;
  clientData: string;
begin
  if Error <> 0 then
    Exit;
  Client := Sender as TGpProxyClient;
  clientData := Client.ReceiveStr;
  if clientData <> '' then begin
    DoClientDataAvailable(Client, clientData);
    ReceivedFromClient(Client, clientData);
  end;
end; { TGpGenericProxy.ProxyClientDataAvailable }

procedure TGpGenericProxy.RemoteDnsLookupDone(sender: TObject; error: word);
begin
  if Error <> 0 then
    InternalClose(TWSocket(Sender).Owner as TGpProxyClient)
  else begin
    DoRemoteDnsLookupDone(TWSocket(Sender).Owner as TGpProxyClient);
    with Sender as TWSocket do begin
      Addr := DnsResult;
      Connect;
    end;
  end;
end; { TGpGenericProxy.RemoteDnsLookupDone }

{:Handler for the remote socket's OnSessionClosed event. Call OnRemoteDisconnect
  handler, then close client socket.
}
procedure TGpGenericProxy.RemoteSessionClosed(sender: TObject; error: word);
var
  Client: TGpProxyClient;
begin
  if Error <> 0 then
    Exit;
  Client := TWSocket(Sender).Owner as TGpProxyClient;
  DoRemoteDisconnect(Client);
  InternalClose(Client);
end; { TGpGenericProxy.RemoteSessionClosed }

{:Send text to the socket but only if socket is alive and connected.
}
procedure TGpGenericProxy.SendText(socket: TWSocket; data: string);
begin
  if assigned(socket) and (socket.State = wsConnected) then try
    socket.SendStr(data);
  except end; // socket may get disconnected during the send - ignore the error in such case
end; { TGpGenericProxy.SendText }

{:Set list of allowed IP addresses.
}
procedure TGpGenericProxy.SetAllowedIP(const Value: TStrings);
begin
  FAllowedIP.Assign(Value);
end; { TGpGenericProxy.SetAllowedIP }

{:Set class of the client sockets. If proxy is Active, class won't be modified.
}
procedure TGpGenericProxy.SetClientClass(const Value: TGpProxyClientClass);
begin
  if not Active then
    FWSocketServer.ClientClass := Value
  else
    raise Exception.Create('ClientClass property can only be modified when proxy is not active');
end; { TGpGenericProxy.SetClientClass }

{:Set local address. If proxy is Active, local address won't be changed.
}
procedure TGpGenericProxy.SetLocalAddress(const Value: string);
begin
  if not Active then
    FLocalAddress := Value
  else
    raise Exception.Create('LocalAddress property can only be modified when proxy is not active');
end; { TGpGenericProxy.SetLocalAddress } 

{:Set proxy port. If proxy is Active, port won't be changed.
}
procedure TGpGenericProxy.SetPort(const Value: integer);
begin
  if not Active then
    FPort := Value
  else
    raise Exception.Create('Port property can only be modified when proxy is not active');
end; { TGpGenericProxy.SetPort }

{:Handler for the TWSocketServer's OnClientConnect event. Set connected socket's
  event handlers, increment socket count, and call OnClientConnect handler.
}
procedure TGpGenericProxy.WSocketServerClientConnect(sender: TObject;
  Client: TWSocketClient; error: word);
begin
  if Error <> 0 then
    Exit;
  with Client as TGpProxyClient do begin
    Received        := '';
    OnDataAvailable := ProxyClientDataAvailable;
    OnBgException   := BgException;
    LineMode        := false;
    LastSendTime    := GetTickCount;
    FClientCount    := TWSocketServer(Server).ClientCount;
  end;
  DoClientConnect(Client as TGpProxyClient);
end; { TGpGenericProxy.WSocketServerClientConnect }

procedure TGpGenericProxy.WSocketServerClientCreate(sender: TObject;
  Client: TWSocketClient);
begin
end; { TGpGenericProxy.WSocketServerClientCreate }

{:Handler for the TWSocketServer's OnClientDisconnect event. Decrement socket
  count and call OnClientDisconnect handler.
}
procedure TGpGenericProxy.WSocketServerClientDisconnect(sender: TObject;
  Client: TWSocketClient; error: word);
var
  _Client: TGpProxyClient;
begin
  _Client := Client as TGpProxyClient;
  FClientCount := TWSocketServer(_Client.Server).ClientCount-1;
  DoClientDisconnect(_Client);
end; { TGpGenericProxy.WSocketServerClientDisconnect }

{:Handler for the TWSocketServer's OnSessionClosed event. Disconnect client
  socket and call OnServerClosed handler.
}
procedure TGpGenericProxy.WSocketServerSessionClosed(sender: TObject;
  error: word);
begin
  if assigned(TWSocket(Sender).Owner) then
    with TWSocket(Sender).Owner as TGpProxyClient do
      ShutDown(1);
  DoServerClosed(error);
end; { TGpGenericProxy.WSocketServerSessionClosed }

{:Handler for the TWSocketServer's OnSessionConnected event. Call
  OnServerListening handler.
}
//procedure TGpGenericProxy.WSocketServerSessionConnected(sender: TObject;
//  error: word);
//begin
//  DoServerListening;
//end; { TGpGenericProxy.WSocketServerSessionConnected }

{ TGpHttpProxy }

{:Create proxy object.
}
constructor TGpHttpProxy.Create(AOwner: TComponent);
var
  iProxy: TGpProxyType;
begin
  inherited;
  FPort := 8080;
  FEnabledTypes := [ptHTTP..ptTCPTunnel];
  FResponse := TGpProxyStrings.Create;
  for iProxy := Low(FNextHopProxy) to High(FNextHopProxy) do
    FNextHopProxy[iProxy] := TGpProxyData.Create(8080);
end; { TGpHttpProxy.Create }

{:Destroy proxy object.
}
destructor TGpHttpProxy.Destroy;
var
  iProxy: TGpProxyType;
begin
  try // raising exception during service destruction is not a good idea
    CloseSocketServer;
    for iProxy := Low(FNextHopProxy) to High(FNextHopProxy) do
      FreeAndNil(FNextHopProxy[iProxy]);
    FreeAndNil(FResponse);
    inherited;
  except end;
end; { TGpHttpProxy.Destroy }

{:OnClientHeaderAvailable forwarder.
}
procedure TGpHttpProxy.DoClientHeaderAvailable(Client: TGpProxyClient;
  url: string; var header, proto, user, pass, host, port, path, hdrHost: string;
  var ignoreNextHopProxy: boolean; var returnContent: string);
begin
  ignoreNextHopProxy := false;
  returnContent := '';
  if assigned(FOnClientHeaderAvailable) then
    FOnClientHeaderAvailable(self,Client,url,header,proto,user,pass,host,port,
      path,hdrHost,ignoreNextHopProxy,returnContent);
end; { TGpHttpProxy.DoClientHeaderAvailable }

{:OnTunnelRequest forwarder.
}
procedure TGpHttpProxy.DoTunnelRequest(Client: TGpProxyClient; var ahost,
  aport: string; var ignoreNextHopProxy: boolean; var returnContent: string);
begin
  if assigned(FOnTunnelRequest) then
    FOnTunnelRequest(Self, Client, ahost, aport, ignoreNextHopProxy, returnContent);
end; { TGpHttpProxy.DoTunnelRequest }

{:Extract specified header line.
  @param   header    HTTP response header.
  @param   headerTag Name of the line to be extracted.
  @returns Contents of the specified line without the leading tag or empty
           string if the line doesn't exist.
  @since   2001-11-07
}
function TGpHttpProxy.ExtractHeader(header, headerTag: string): string;
var
  p: integer;
begin
  p := Pos(#13#10+UpperCase(headerTag)+':',UpperCase(header));
  if p = 0 then
    Result := ''
  else begin
    Delete(header,1,p+Length(headerTag)+2);
    header := TrimLeft(header);
    p := Pos(#13#10,header);
    if p = 0 then
      Result := header
    else
      Result := Copy(header,1,p-1);
  end;
end; { TGpHttpProxy.ExtractHeader }

{:Return next-hop proxy.
  @param   index ptHTTP - return HTTP proxy, ptTCPTunnel - return TCP Tunnel
                 proxy
}
function TGpHttpProxy.GetNextHopProxy(index: TGpProxyType): TGpProxyData;
begin
  Result := FNextHopProxy[index];
end; { TGpHttpProxy.GetNextHopProxy }

{:Process HTTP or TCP Tunnel header.
}
procedure TGpHttpProxy.ProcessHeader(Client: TGpProxyClient);
var
  ahost        : string;
  aport        : string;
  header       : string;
  returnContent: string;
begin
  returnContent := '';
  header := Client.Received;
  if SameText(FirstEl(header,' ',-1),'CONNECT') then begin
    // TCP Tunnel proxy request
    Client.SetProxyType(ptTCPTunnel);
    if not FIPSec.IsAllowed(Client.PeerAddr) then
      returnContent := Response.sTCPTunnelIPForbidden.Text
    else if not (ptTCPTunnel in EnabledTypes) then
      returnContent := Response.sTCPTunnelClosed.Text
    else if not ProcessTCPTunnelHeader(Client,header,ahost,aport,returnContent) then
      returnContent := Response.sTCPTunnelBadRequest.Text;
  end
  else begin
    // HTTP proxy request
    Client.SetProxyType(ptHTTP);
    if not FIPSec.IsAllowed(Client.PeerAddr) then
      returnContent := Response.sHTTPIPForbidden.Text
    else if not (ptHTTP in EnabledTypes) then
      returnContent := Response.sHTTPClosed.Text
    else if not ProcessHTTPHeader(Client,header,ahost,aport,returnContent) then
      returnContent := Response.sHTTPBadRequest.Text;
  end; //else SameText()
  // Header parsed, create remote socket.
  if returnContent = '' then begin
    with Client do begin
      CreateRemoteSocket;
      Received              := header;
      RemoteSocket.Port     := aport;
      RemoteSocket.LineMode := false;
      HookRemoteEvents(RemoteSocket);
      RemoteSocket.DnsLookup(ahost);
      DoRemoteSocketPrepared(Client);
    end; //with
  end
  else begin
    Client.DestroyRemoteSocket;
    Client.RemoteContent := returnContent;
  end;
  Client.GotHeader := true;
end; { TGpHttpProxy.ProcessHeader }

{:Process HTTP header.
  @param   header        (in)  Received header.
                         (out) Modified header, ready to be sent to the remote
                               socket.
  @param   ahost         (out) Remote socket's IP address.
  @param   aport         (out) Remote socket's port.
  @param   returnContent (out) Non-static content to be returned. If '',
                               connection to remote socket will be made instead.
  @returns True if header was valid.
}
function TGpHttpProxy.ProcessHTTPHeader(Client: TGpProxyClient;
  var header, ahost, aport, returnContent: string): boolean;

  function MakeUrl(aproto, auser, apass, ahost, aport, apath: string): string;
  begin
    Result := aproto;
    if Last(Result,1) = ':' then
      Result := Result + '//'
    else if Last(Result,1) <> '/' then
      Result := Result + '://';
    if auser <> '' then begin
      Result := Result + auser;
      if apass <> '' then
        Result := Result + ':' + apass;
      Result := Result + '@';
    end;
    Result := Result + ahost;
    if (aport <> '') and (aport <> '80') then
      Result := Result + ':' + aport;
    Result := Result + apath;
  end; { MakeUrl }

var
  apass             : string;
  apath             : string;
  aproto            : string;
  auser             : string;
  command           : string;
  hdrHost           : string;
  ignoreNextHopProxy: boolean;
  p1                : integer;
  p2                : integer;
  s                 : string;
  url               : string;

begin { TGpHttpProxy.ProcessHTTPHeader }
  Result := false;
  // extract url from GET/POST header
  s := header;
  p1 := Pos(' ',s);
  if p1 > 0 then begin
    command := First(s,p1-1);
    Delete(s,1,p1);
    s := TrimLeft(s);
    p2 := Pos(' ',s);
    if p2 > 0 then begin
      url := Copy(s,1,p2-1);
      ParseURL(url,aproto,auser,apass,ahost,aport,apath);
      if aport = '' then
        aport := '80';
      hdrHost := ExtractHeader(header,'Host');
      returnContent := '';
      ignoreNextHopProxy := false;
      DoClientHeaderAvailable(Client,url,header,aproto,auser,apass,ahost,aport,
        apath,hdrHost,ignoreNextHopProxy,returnContent);
      if (NextHopHTTP.Address <> '') and (not ignoreNextHopProxy) and
         (returnContent = '') then //replace host information with proxy
      begin
        Delete(header,p1+1,p2-1);
        Insert(MakeUrl(aproto,auser,apass,ahost,aport,apath),header,p1+1);
        if NextHopHTTP.Username <> '' then begin
          // Insert 'Proxy-Authorization' header
          p1 := Pos(CRLF+CRLF,header);
          Insert(CRLF+'Proxy-Authorization: Basic '+
            EncodeStr(encBase64, NextHopHTTP.Username+':'+NextHopHTTP.Password),
            header,p1);
        end;
        ReplaceHeader(header,'Host',hdrHost);
        aport := IntToStr(FNextHopProxy[ptHTTP].Port);
        ahost := FNextHopProxy[ptHTTP].Address;
        Client.UsingNextHop := true;
      end
      else if SameText(command,'OPTIONS') and (ahost = '*') then
        Exit
      else begin
        // Any of the URL parts may have changed in the event handler - modify the header.
        Delete(header,p1+1,p2-1);
        if SameText(command,'OPTIONS') then
          Insert('*',header,p1+1)
        else
          Insert(apath,header,p1+1);
        ReplaceHeader(header,'Host',hdrHost);
        if auser <> '' then begin
          // Insert 'Authorization' header
          p1 := Pos(CRLF+CRLF,header);
          Insert(CRLF+'Authorization: Basic '+EncodeStr(encBase64, auser+ ':'+apass),
            header,p1);
        end;
        Client.UsingNextHop := false;
      end;
      Result := true;
    end; //else p2 > 0
  end; //else p1 > 0
end; { TGpHttpProxy.ProcessHTTPHeader }

{:Process TCP Tunnel header.
  @param   header        (in) Received header.
                         (out) Modified header, ready to be sent to the remote
                               socket.
  @param   ahost         (out) Remote socket's IP address.
  @param   aport         (out) Remote socket's port.
  @param   returnContent (out) Non-static content to be returned. If '',
                               connection to remote socket will be made instead.
  @returns True if header was valid.
}
function TGpHttpProxy.ProcessTCPTunnelHeader(Client: TGpProxyClient;
  var header, ahost, aport, returnContent: string): boolean;
var
  apass             : string;
  apath             : string;
  aproto            : string;
  auser             : string;
  ignoreNextHopProxy: boolean;
  p1                : integer;
  s                 : string;
begin
  //Handles TCP Tunnel requests of the following form:
  //  CONNECT 161.69.2.7:21 HTTP/1.1
  //  User-Agent: WinProxy (Version 4.0 R1b)
  //  Host: 161.69.2.7
  //  Pragma: no-cache
  Result := false;
  s := FirstEl(header,#13,-1);
  if NumElements(s,' ',-1) = 3 then begin
    s := NthEl(s,2,' ',-1);
    if NumElements(s,':',-1) = 2 then begin
      aproto := '';
      auser := '';
      apass := '';
      apath := '';
      ahost := NthEl(s,1,':',-1);
      aport := NthEl(s,2,':',-1);
      returnContent := '';
      ignoreNextHopProxy := false;
      DoTunnelRequest(Client,ahost,aport,ignoreNextHopProxy,
        returnContent);
      if (NextHopTCPTunnel.Address <> '') and (not ignoreNextHopProxy) and
         (returnContent = '') then // replace host information with proxy
      begin
        // ahost, aport may have changed - modify the header
        header := FirstEl(header,' ',-1)+' '+ahost+':'+aport+' '+
          ButFirstNEl(header,2,' ',-1);
        if NextHopTCPTunnel.Username <> '' then begin
          // Insert 'Proxy-Authorization' header
          p1 := Pos(CRLF+CRLF,header);
          Insert(CRLF+'Proxy-Authorization: Basic '+
            EncodeStr(encBase64, NextHopTCPTunnel.Username+':'+NextHopTCPTunnel.Password),
            header,p1);
        end;
        aport := IntToStr(FNextHopProxy[ptTCPTunnel].Port);
        ahost := FNextHopProxy[ptTCPTunnel].Address;
        Client.UsingNextHop := true;
      end
      else begin
        // strip TCP Tunnel request from the header
        p1 := Pos(CRLF+CRLF,header);
        header := ButFirst(header,p1+3);
        Client.UsingNextHop := false;
      end;
      Result := true;
    end; //if NumElements(s,':',-1)
  end; //if NumElements(s,' ',-1)
end; { TGpHttpProxy.ProcessTCPTunnelHeader }

{:Process data received from the client. Accumulate data until full header is
  received, then process the header and either forward or reject the connection.
}
procedure TGpHttpProxy.ReceivedFromClient(Client: TGpProxyClient;
  clientData: string);
begin
  Client.Received := Client.Received + clientData;
  if not Client.GotHeader then begin
    if Pos(CRLF+CRLF,Client.Received) > 0 then
      ProcessHeader(Client) // will set gotHeader
    else
      Exit;
  end;
  if Client.GotHeader and (Client.Received <> '') then begin
    if not assigned(Client.RemoteSocket) then begin
      SendText(Client,Client.RemoteContent);
      Self.InternalClose(Client);
      Client.Received := '';
    end
    else if (Client.RemoteSocket.State = wsConnected) then begin
      SendText(Client.RemoteSocket,Client.Received);
      Client.Received := '';
    end;
  end;
end; { TGpHttpProxy.ReceivedFromClient }

{:Handler for the remote socket's OnDataAvailable event. Call
  OnRemoteDataAvailable handler and forward the received data to the client
  socket.
}
procedure TGpHttpProxy.RemoteDataAvailable(sender: TObject; error: word);
var
  Client    : TGpProxyClient;
  fromRemote: string;
  p         : integer;
begin
  if Error <> 0 then
    Exit;
  Client := TWSocket(Sender).Owner as TGpProxyClient;
  fromRemote := Client.RemoteSocket.ReceiveStr;
  if fromRemote <> '' then begin
    if (Client.ProxyType = ptTCPTunnel) and Client.UsingNextHop and
       (not Client.GotResponseHeader) then
    begin
      if Client.UsingNextHop then begin
        Client.RemoteReceived := Client.RemoteReceived + fromRemote;
        p := Pos(CRLF+CRLF,Client.RemoteReceived);
        if p > 0 then begin
          SendText(Client,First(Client.RemoteReceived,p+3));
          fromRemote := ButFirst(Client.RemoteReceived,p+3);
          Client.GotResponseHeader := true;
        end;
        if not Client.GotResponseHeader then
          Exit;
      end;
    end;
    DoRemoteDataAvailable(Client,fromRemote);
    if Client.State = wsConnected then
      SendText(Client,fromRemote)
    else // should not occur
      Client.RemoteSocket.ShutDown(1);
  end;
end; { TGpHttpProxy.RemoteDataAvailable }

{:Handler for the remote socket's OnSessionConnected event. Call OnRemoteConnect
  handler, then process received data (if any).
}
procedure TGpHttpProxy.RemoteSessionConnected(sender: TObject; error: word);
var
  Client: TGpProxyClient;
begin
  Client := TWSocket(Sender).Owner as TGpProxyClient;
  DoRemoteConnect(Client);
  if Error <> 0 then
    Exit;
  if (Client.ProxyType = ptTCPTunnel) and (not Client.UsingNextHop) then begin
    // Send 200 Connection established
    SendText(Client,Response.sTCPTunnelEstablished.Text);
    Client.GotResponseHeader := true;
  end;
  ReceivedFromClient(Client,Client.ReceiveStr);
end; { TGpHttpProxy.RemoteSessionConnected }

{:Replace HTTP header.
  @param   header    HTTP header.
  @param   headerTag Tag of the HTTP line.
  @param   newValue  New value of the header line.
  @since   2001-11-07
}
procedure TGpHttpProxy.ReplaceHeader(var header: string; headerTag,
  newValue: string);
var
  p     : integer;
  prefix: string;
begin
  p := Pos(#13#10+UpperCase(headerTag)+':',UpperCase(header));
  if p = 0 then begin
    p := Pos(#13#10#13#10,header);
    Insert(#13#10+headerTag+': '+newValue,header,p);
  end
  else begin
    prefix := Copy(header,1,p+Length(headerTag)+2);
    Delete(header,1,p+Length(headerTag)+2);
    header := TrimLeft(header);
    p := Pos(#13#10,header);
    if p = 0 then
      p := Length(header)+1;
    Delete(header,1,p-1);
    header := prefix + ' ' + newValue + header;
  end;
end; { TGpGenericProxy.ReplaceHeader }

{:Set next-hop proxy data.
  @param   index ptHTTP - return HTTP proxy, ptTCPTunnel - return TCP Tunnel
                 proxy
}
procedure TGpHttpProxy.SetNextHopProxy(index: TGpProxyType;
  const Value: TGpProxyData);
begin
  FNextHopProxy[index].Assign(Value);
end; { TGpHttpProxy.SetNextHopProxy }

{:Set response strings.
}
procedure TGpHttpProxy.SetResponse(const Value: TGpProxyStrings);
begin
  FResponse.Assign(Value);
end; { TGpHttpProxy.SetResponse }

end.
