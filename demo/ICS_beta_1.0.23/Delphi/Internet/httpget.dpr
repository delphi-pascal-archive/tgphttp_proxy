program HttpGet;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  HttpGet1 in 'HttpGet1.pas' {HttpGetForm};

{$R *.RES}

begin
  Application.CreateForm(THttpGetForm, HttpGetForm);
  Application.Run;
end.
