program TcpSrv;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}
{%TogetherDiagram 'ModelSupport\TcpSrv1\default.txaPackage'}
{%TogetherDiagram 'ModelSupport\TcpSrv\default.txaPackage'}
{%TogetherDiagram 'ModelSupport\WSocketS\default.txaPackage'}
{%TogetherDiagram 'ModelSupport\WSocket\default.txaPackage'}
{%TogetherDiagram 'ModelSupport\default.txvpck'}

uses
  Forms,
  TcpSrv1 in 'TcpSrv1.pas' {TcpSrvForm},
  WSocket in '..\VC32\WSocket.pas',
  WSocketS in '..\VC32\WSocketS.pas';

{$R *.RES}

begin
  Application.CreateForm(TTcpSrvForm, TcpSrvForm);
  Application.Run;
end.
