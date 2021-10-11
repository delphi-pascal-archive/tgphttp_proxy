program SocksTst;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  Socks1 in 'Socks1.pas' {SocksTestForm};

{$R *.RES}

begin
  Application.CreateForm(TSocksTestForm, SocksTestForm);
  Application.Run;
end.
