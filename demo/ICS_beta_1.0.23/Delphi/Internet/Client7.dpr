program Client7;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  Cli7 in 'Cli7.pas' {Cli7Form};

{$R *.RES}

begin
  Application.CreateForm(TCli7Form, Cli7Form);
  Application.Run;
end.
