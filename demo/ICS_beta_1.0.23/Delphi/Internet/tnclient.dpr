program TnClient;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  TnCli1 in 'TnCli1.pas' {TelnetForm};

{$R *.RES}

begin
  Application.CreateForm(TTelnetForm, TelnetForm);
  Application.Run;
end.
