GpHTTPProxy/GpHTTPProxyDemo are generic proxy component (currently without
support for caching) and simple demonstration program. TGpHTTPProxy is using
TWSocketServer component from Francois Piette
(http://www.rtfm.be/fpiette/icsuk.htm). Both server and demo are based on
SocketSpy program by Wilfried Mestdagh. Both are release as freeware.

GpHTTPProxy home page is at http://17slon.com/gp/gp/index.htm#GpHTTPProxy.

Primoz Gabrijelcic
gabr@17slon.com
http://17slon.com/gp

======== Original SocketSpy documentation follows ========

This version of Socketspy uses TWSocketServer. This spying program is a kind of
proxy displaying all traffic going through it. It can display the traffic in
ascii or in hex-ascii (for binary traffic). It's primary intention is for
debugging purposes.

You will need to install Francois Piette's TWSocketServer component
(http://www.rtfm.be/fpiette/icsuk.htm). No additional components are required.

Usage is very simple: You set the listening port to the one that your client TCP
program must connect to, then set the address and port to the machine where you
want to connect to and finally click on 'Listen'. Multiple connections are shown
in different colors.

A few examples on how to use it:

* you want to see the traffic with IE running on same machine as SocketSpy, and
  you have to connect through the proxy server of your ISP on port 8080. In IE,
  set 'connection', 'lan settings' to 'use proxy server'. Fill in 'localhost'
  and port 80. Set the listen port in SocketSpy to 80, the address to the proxy
  of your ISP, and the port to 8080. You will notice that connecting to some
  sites requires multiple connections.

* you have created a client/server application running on same machine as
  socketspy and want to check out traffic. Your server is listening on port 9000
  (or any other port). Set the port and address of your client to 9001 and
  localhost. Start SocketSpy listening on port 9001 and set address and port of
  remote to localhost and 9000.

* you are connected to the internet and someone else also connected to the
  internet wants to connect to a machine on your LAN (which is on a private
  network and therefore not routable). Then you ask to connect to your machine
  that is connected to the internet let's say on port 9000. Run SocketSpy on the
  machine that is connected to the internet and set the port to 9000. Set
  machine and port of SocketSpy to the machine on your LAN and the port the
  server program is listening on. Thats all.

The program is free for use only thing I ask is that you not claim to written
the original code if you distribute it. And of course if you make any money with
it, then a small gift is welcome ;-))

You can reach me for questions, or just to say 'hello' at:
w.mestdagh@pandora.be
wilfried_sonal@compuserve.com
wilfried@sonal.be
And of course on the TWSocket mailing list where your questions can also reach
others

The home page of the company I work for is: www.sonal.be
but it is still under construction (not by me)

Many thanks also to Simon Steed [toto@xploiter.com] who corrected my English in
this document. (pleasure Wilfried :o))

If you have CBuilder standard, then it will not compile because assembler is
used in the code for the debugstring. Then you can change the debugstring code
in this very simple, but also very slow code:

function DebugString( Log: string ): string;
var
  i      : integer;
  nAddr  : integer;
  HexLine, txtLine, TmpLine : string;
begin
  result := '';
  nAddr  := 0;
  while Length(Log) > 0 do begin
    tmpLine := copy(Log, 1, 16);
    Delete(Log, 1, 16);
    HexLine := '';
    txtLine := '';
    for i := 1 to 16 do begin
       if i <= length( tmpLine ) then begin
         HexLine := HexLine + IntToHex(ord(TmpLine[i]), 2);
         txtLine := txtLine + iif( ord(TmpLine[i]) < $20 , '.' , tmpLine[i] );
         end
       else begin
         HexLine := HexLine + '  ';
         txtLine := txtLine + ' ';
       end;
       HexLine := HexLine + iif( i = 8 , '-' , ' ' );
    end;
    Result := Result + IntToHex( nAddr , 4 ) + '  ' + HexLine + TxtLine + #13#10;
    nAddr  := nAddr + $10;
   end;
end;

======== End of Original SocketSpy documentation ========