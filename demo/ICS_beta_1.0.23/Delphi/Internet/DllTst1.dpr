program DllTst1;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  DllTst_1 in 'DllTst_1.pas' {DllTestForm};

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TDllTestForm, DllTestForm);
  Application.Run;
end.
