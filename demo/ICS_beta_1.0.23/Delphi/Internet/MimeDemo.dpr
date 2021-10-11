program MimeDemo;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  MIMEDMO1 in 'MIMEDMO1.PAS' {MimeDecodeForm};

{$R *.RES}

begin
  Application.CreateForm(TMimeDecodeForm, MimeDecodeForm);
  Application.Run;
end.
