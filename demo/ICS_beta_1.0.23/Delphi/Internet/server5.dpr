program server5;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  Srv5 in 'Srv5.pas' {ServerForm};

{$R *.RES}

begin
  Application.CreateForm(TServerForm, ServerForm);
  Application.Run;
end.
