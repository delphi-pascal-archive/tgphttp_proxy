unit demoMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, WSockets, GpHTTPProxy;

type
  TSpyProxyClient = class(TGpProxyClient)
  public
    Color: TColor;
    destructor Destroy; override;
  end; { TSpyProxyClient }

type
  TMain = class(TForm)
    BlockURL       : TEdit;
    cbProxy        : TCheckBox;
    GpHTTPProxy    : TGpHTTPProxy;
    GpHttpsProxy   : TGpHttpProxy;
    grpBlockAccess : TGroupBox;
    grpConnection  : TGroupBox;
    grpProxy       : TGroupBox;
    grpRedirectHost: TGroupBox;
    Label1         : TLabel;
    Label2         : TLabel;
    Label3         : TLabel;
    Label4         : TLabel;
    Label5         : TLabel;
    ListenBtn      : TButton;
    LocalPoort     : TEdit;
    LocalSSLPoort  : TEdit;
    RedirectSource : TEdit;
    RedirectTarget : TEdit;
    RemoteAddr     : TEdit;
    RemotePort     : TEdit;
    Label6: TLabel;
    Memo1: TMemo;
    Label7: TLabel;
    Label8: TLabel;
    procedure cbProxyClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure GpHTTPProxyClientConnect(Sender: TObject; Client: TGpProxyClient);
    procedure GpHTTPProxyClientDataAvailable(Sender: TObject; Client: TGpProxyClient;
      data: string);
    procedure GpHTTPProxyClientDisconnect(Sender: TObject; Client: TGpProxyClient);
    procedure GpHTTPProxyClientHeaderAvailable(Sender: TObject; Client: TGpProxyClient;
      url: string; var header, proto, user, pass, host, port, path, hdrHost: string;
      var ignoreNextHopProxy: boolean; var returnContent: string);
    procedure GpHTTPProxyRemoteConnect(Sender: TObject; Client: TGpProxyClient);
    procedure GpHTTPProxyRemoteDataAvailable(Sender: TObject; Client: TGpProxyClient;
      data: string);
    procedure GpHTTPProxyRemoteSocketPrepared(Sender: TObject; Client: TGpProxyClient);
    procedure GpHTTPProxyServerClosed(Sender: TObject; error: word);
    procedure ListenBtnClick(Sender: TObject);
    procedure RemoteAddrChange(Sender: TObject);
  private
  public
    property HTTPProxy: TGpHTTPProxy read GpHTTPProxy;
  end;

var
  Main: TMain;

implementation

uses demoLog, HTTPProt;                                                            

{$R *.DFM}

{ TSpyProxyClient }

destructor TSpyProxyClient.Destroy;
begin
  if not Application.Terminated then begin // Log is destroyed before Main
    Log.TextColor := Color;
    Log.Header    := 'Connection Closed';
    Log.Add('');
  end;
  inherited;
end; { TSpyProxyClient.Destroy }

{ TMain }

procedure TMain.ListenBtnClick(Sender: TObject);
var
  errMsg: string;
begin
  if ListenBtn.Tag = 0 then begin
    with GpHTTPProxy do begin
      ClientClass := TSpyProxyClient;
      Port := StrToIntDef(LocalPoort.Text,1080); LocalPoort.Text := IntToStr(Port);
      errMsg := Listen;
      if errMsg <> '' then begin
        Application.MessageBox(PChar(Format('Port %d is already in use!', [Port])),
          'GpHTTPProxyDemo', MB_OK + MB_ICONERROR);
        Exit;
      end;
    end;
    with GpHttpsProxy do begin
      ClientClass := TSpyProxyClient;
      Port := StrToIntDef(LocalSslPoort.Text,1443); LocalSslPoort.Text := IntToStr(Port);
      errMsg := Listen;
      if errMsg <> '' then begin
        GpHttpProxy.Close;
        Application.MessageBox(PChar(Format('Port %d is already in use!', [Port])),
          'GpHTTPProxyDemo', MB_OK + MB_ICONERROR);
        Exit;
      end;
    end;
    LocalPoort.Enabled := false;
    LocalSslPoort.Enabled := false;
    ListenBtn.Caption := 'Stop Proxy-server';
    ListenBtn.Tag := 1;
  end
  else begin
    GpHTTPProxy.Close;
    GpHttpsProxy.Close;
  end;
end; { TMain.ListenBtnClick }

procedure TMain.cbProxyClick(Sender: TObject);
begin
  if cbProxy.Checked then begin
    RemoteAddr.Enabled := cbProxy.Checked;
    RemotePort.Enabled := cbProxy.Checked;
    GpHTTPProxy.NextHopHttp.Address := RemoteAddr.Text;
    GpHTTPProxy.NextHopHttp.Port := StrToIntDef(RemotePort.Text, 80);
  end
  else
    GpHTTPProxy.NextHopHttp.Address := '';
end; { TMain.cbProxyClick }

procedure TMain.FormCreate(Sender: TObject);
begin
  Constraints.MinWidth := Width;
  Constraints.MaxWidth := Width;
  Constraints.MinHeight := Height;
  Constraints.MaxHeight := Height;
end; { TMain.FormCreate }

procedure TMain.GpHTTPProxyClientConnect(Sender: TObject;
  Client: TGpProxyClient);
const
  aColor: array [1..11] of TColor = (clBlack, clMaroon, clGreen, clOlive,
    clNavy, clPurple, clRed, clLime, clYellow, clBlue, clFuchsia);
var
  numClients: integer;
begin
  numClients := TGpHTTPProxy(Sender).ClientCount;
  with Client as TSpyProxyClient do begin
    LineMode := Log.LineMode1.Checked;
    Label8.Caption := IntToStr(numClients);
    if numClients <= high(aColor) then
      Color := aColor[numClients]
    else
      Color := clBlack;
  end;
end; { TMain.GpHTTPProxyClientConnect }

procedure TMain.GpHTTPProxyClientDataAvailable(Sender: TObject;
  Client: TGpProxyClient; data: String);
begin
  with Client as TSpyProxyClient do begin
    Log.TextColor := Color;
    Log.Header    := 'From Local (' + Client.PeerAddr + ')';
    Log.Add(data);
  end;
end; { TMain.GpHTTPProxyClientDataAvailable }

procedure TMain.GpHTTPProxyClientDisconnect(Sender: TObject; 
  Client: TGpProxyClient);
begin
  with Client as TSpyProxyClient do begin
    with Sender as TGpHTTPProxy do begin
      Label8.Caption := IntToStr(ClientCount);
    end; //with
  end;
end; { TMain.GpHTTPProxyClientDisconnect }

procedure TMain.GpHTTPProxyRemoteConnect(Sender: TObject;
  Client: TGpProxyClient);
begin
  with Client as TSpyProxyClient do begin
    Log.TextColor := Color;
    Log.Header    := 'Connection Opened';
    Log.Add('');
  end;
end; { TMain.GpHTTPProxyRemoteConnect }

procedure TMain.GpHTTPProxyRemoteDataAvailable(Sender: TObject;
  Client: TGpProxyClient; data: String);
begin
  with Client as TSpyProxyClient do begin
    if data <> '' then begin
      Log.TextColor := Color;
      Log.Header    := 'From Remote';
      Log.Add(data);
    end;
  end;
end; { TMain.GpHTTPProxyRemoteDataAvailable }

procedure TMain.GpHTTPProxyServerClosed(Sender: TObject; error: word);
begin
  if not (csDestroying in ComponentState) then begin
    LocalPoort.Enabled := True;
    RemotePort.Enabled := True;
    RemoteAddr.Enabled := True;
    ListenBtn.Caption  := 'Start Proxy-server';
    ListenBtn.Tag      :=  0;
  end;
end; { TMain.GpHTTPProxyServerClosed }

procedure TMain.RemoteAddrChange(Sender: TObject);
begin
  GpHTTPProxy.NextHopHttp.Address := RemoteAddr.Text;
  GpHTTPProxy.NextHopHttp.Port := StrToIntDef(RemotePort.Text, 80);
end; { TMain.RemoteAddrChange }

procedure TMain.GpHTTPProxyRemoteSocketPrepared(Sender: TObject;
  Client: TGpProxyClient);
begin
  Client.RemoteSocket.LineMode := Log.LineMode1.Checked;
end; { TMain.GpHTTPProxyRemoteSocketPrepared }

procedure TMain.GpHTTPProxyClientHeaderAvailable(Sender: TObject;
  Client: TGpProxyClient; url: String; var header, proto, user, pass,
  host, port, path, hdrHost: String; var ignoreNextHopProxy: Boolean;
  var returnContent: String);
const
  CBlocked =
    'HTTP/1.1 403 Forbidden'#13#10+
    'Connection: close'#13#10+
    'Content-Type: text/html'#13#10#13#10+
    '<HTML><HEAD><TITLE>Blocked</TITLE></HEAD><BODY><H1>Blocked</H1>'#13#10+
    'Access to the requested URL <B>%s</B> was not allowed.'#13#10+
    '</BODY></HTML>'#13#10;
begin
  Memo1.Text := url;
  if CompareText(host,RedirectSource.Text) = 0 then begin
    host := RedirectTarget.Text;
    hdrHost := RedirectTarget.Text;
  end;
  if CompareText(host,BlockURL.Text) = 0
  then returnContent:=Format(CBlocked,[host]);
end;

end.
