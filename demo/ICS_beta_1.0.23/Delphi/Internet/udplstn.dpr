program UdpLstn;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  UdpLstn1 in 'UdpLstn1.pas' {MainAutoForm};

{$R *.RES}

begin
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
