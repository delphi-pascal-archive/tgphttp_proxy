program Pop3Mime;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  POP3MIM1 in 'POP3MIM1.PAS' {MimeDecodeForm};

{$R *.RES}

begin
  Application.CreateForm(TMimeDecodeForm, MimeDecodeForm);
  Application.Run;
end.
