program Finger;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  Finger1 in 'Finger1.pas' {FingerDemoForm};

{$R *.RES}

begin
  Application.CreateForm(TFingerDemoForm, FingerDemoForm);
  Application.Run;
end.
