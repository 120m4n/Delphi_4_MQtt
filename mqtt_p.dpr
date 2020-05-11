program mqtt_p;

uses
  Forms,
  uMain in 'uMain.pas' {frmMain},
  mqtt in 'mqtt.pas',
  UUtf8 in 'UUtf8.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
