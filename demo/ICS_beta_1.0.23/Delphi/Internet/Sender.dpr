program Sender;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  Sender1 in 'Sender1.pas' {SenderForm};

{$R *.RES}

begin
  Application.CreateForm(TSenderForm, SenderForm);
  Application.Run;
end.
