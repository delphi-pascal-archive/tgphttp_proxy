program DnsLook;

{%TogetherDiagram 'ModelSupport\default.txaPackage'}

uses
  Forms,
  DnsLook1 in 'DnsLook1.pas' {DnsLookupForm};

{$R *.RES}

begin
  Application.CreateForm(TDnsLookupForm, DnsLookupForm);
  Application.Run;
end.
