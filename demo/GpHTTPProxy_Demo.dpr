{:
  Demo for TGpHTTPProxy component. Uses Francois Piette's ICS suite
  (http://www.rtfm.be/fpiette/icsuk.htm). Based on the work of Wilfried
  Mestdagh. This code is freeware.

  Primoz Gabrijelcic, gabr@17slon.com, http://17slon.com/gp

  Maintainer         : Primoz Gabrijelcic
  Version            : 2.0
  Creation date      : 2000-03-08
  Last modification  : 2004-03-17

  Version history:
    2.0: 2004-03-17
      - Adapted for GpHTTPProxy 2.0.
      - Added HTTPS support to the demo.
    1.03: 2001-10-28
      - OnClientHeaderAvailable modified to the new template (GpHTTPProxy 1.02)
        and changed to return '403' on blocked page (was '404'). Thanks go to
        the Stanislav Korotky for help and suggestions.
    1.02: 2001-01-29
      - Added demo for redirection and blocking.
    1.01: 2000-03-17
      - 'Use next-hop proxy' is now unchecked by default.
      - There was a nasty bug in the demo - if you tried to listed on port that
        was already in use, demo behaved as if everthing is OK but in reality
        it was not listening at all.
    1.0: 2000-03-13
      - First release.
}

program GpHTTPProxy_Demo;

uses
  Forms,
  demoMain in 'demoMain.pas' {Main},
  demoLog in 'demoLog.pas' {Log};

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.CreateForm(TLog, Log);
  Application.Run;
end.
