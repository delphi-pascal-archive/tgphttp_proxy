program MimeTst;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  MimeTst1 in 'MimeTst1.pas' {MimeTestForm};

{$R *.RES}

begin
  Application.CreateForm(TMimeTestForm, MimeTestForm);
  Application.Run;
end.
