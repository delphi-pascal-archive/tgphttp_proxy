program DynCli;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  DynCli1 in 'DynCli1.pas' {DynCliForm};

{$R *.RES}

begin
  Application.CreateForm(TDynCliForm, DynCliForm);
  Application.Run;
end.
