program MailSnd;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  MailSnd1 in 'MailSnd1.pas' {SmtpTestForm};

{$R *.RES}

begin
  Application.CreateForm(TSmtpTestForm, SmtpTestForm);
  Application.Run;
end.
