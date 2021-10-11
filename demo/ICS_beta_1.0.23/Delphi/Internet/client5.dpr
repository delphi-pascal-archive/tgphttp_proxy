program client5;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  Cli5 in 'Cli5.pas' {ClientForm};

{$R *.RES}

begin
  Application.CreateForm(TClientForm, ClientForm);
  Application.Run;
end.
