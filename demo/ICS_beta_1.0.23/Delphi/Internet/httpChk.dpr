program httpChk;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  HttpChk1 in 'HttpChk1.pas' {CheckUrlForm};

{$R *.RES}

begin
  Application.CreateForm(TCheckUrlForm, CheckUrlForm);
  Application.Run;
end.
