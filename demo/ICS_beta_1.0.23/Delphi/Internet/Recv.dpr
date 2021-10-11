program Recv;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  Recv1 in 'Recv1.pas' {RecvForm};

{$R *.RES}

begin
  Application.CreateForm(TRecvForm, RecvForm);
  Application.Run;
end.
