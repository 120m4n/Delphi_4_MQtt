unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, mqtt,
  StdCtrls;


type
  T_user_obj = record
    Data: Integer;
  end;

  P_user_obg = ^T_user_obj;

const
  WM_MQTT_MESSAGES = WM_USER + 1;

type
  T_mqtt_msg_id = (ON_CONNECT_ID, ON_DISCONNECT_ID, ON_PUBLISH_ID, ON_MESSAGE_ID, ON_SUBSCRIBE_ID, ON_UNSUBSCRIBE_ID, ON_LOG_ID);

type
  T_win_message = record
    description: string;
    id: T_mqtt_msg_id;
    rc: Integer; // ÃŠÃ®Ã¤ Ã± Ã¯Ã°Ã¨Ã·Ã¨Ã­Ã®Ã© Ã¢Ã»Ã§Ã®Ã¢Ã 
    mosquitto_message: P_mosquitto_message;
  end;

type
  P_win_message = ^T_win_message;

type
  T_received_MQTT_msg = record
    mid: Integer;
    topic: string;
    payload: string;
    QoS: Integer;
    retain: boolean;
  end;

type
  TfrmMain = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Memo1: TMemo;
    Button3: TButton;
    edtPayLoad: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure act_DisconnectExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    f_mosq: Pmosquitto;
    f_session_started: boolean;
    f_clean_session: Byte;
    f_retain: Byte;
    f_user_obj: T_user_obj;
    f_user_id: AnsiString;
    f_will_payload: AnsiString;
    f_will_payload_len: Integer;
    f_will_topic: AnsiString;
    f_user_name: AnsiString;
    f_user_password: AnsiString;
    f_hostname: AnsiString;
    f_port: Integer;
    f_keepalive: Integer;
    f_connected: boolean;
    f_connect_result: Integer;
    f_disconnect_result: Integer;
    f_pub_id: Integer;
    f_pub_topic: AnsiString;
    f_pub_payload_len: Integer;
    f_pub_payload: AnsiString;
    f_pub_qos: Integer;
    f_pub_retain: Byte;
    f_sub_id: Integer;
    f_sub_topic: AnsiString;
    f_sub_qos: Integer;
    f_autosending: boolean;

    procedure Start_session;
    procedure Stop_session;
    procedure Gather_session_parameters;
    procedure Gather_parameters;

    function ConvertStringToUTF8(const str: string; var utf8str: AnsiString): Integer;
    procedure Convert_Topic_To_String(const utf8str: PAnsiChar; var str: string);
    procedure Convert_Payload_To_String(const utf8str: PAnsiChar; sz: Integer; var str: string);

    procedure MessagesgHandler(var Message: TMessage); message WM_MQTT_MESSAGES;
    procedure WriteLog(logstring: string);
    //procedure Publish(topic: string; payload: string; QoS: Integer; retain: boolean);
    procedure ConvertMQTT_msg(mosquitto_message: P_mosquitto_message; var msg: T_received_MQTT_msg);
  end;

  //function Callback_tls_set(buf: PChar; size: Integer; rwflag: Integer; userdata: Pointer): Integer; cdecl;
  procedure Callback_on_connect(mosq: Pmosquitto; obj: Pointer; rc: Integer); cdecl;
  procedure Callback_on_disconnect(mosq: Pmosquitto; obj: Pointer; rc: Integer); cdecl;
  procedure Callback_on_publish(mosq: Pmosquitto; obj: Pointer; mid: Integer); cdecl;
  procedure Callback_on_message(mosq: Pmosquitto; obj: Pointer; mosquitto_message: P_mosquitto_message); cdecl;
  procedure Callback_on_subscribe(mosq: Pmosquitto; obj: Pointer; mid: Integer; qos_count: Integer; granted_qos: PInteger); cdecl;
  procedure Callback_on_unsubscribe(mosq: Pmosquitto; obj: Pointer; mid: Integer); cdecl;
  procedure Callback_on_log(mosq: Pmosquitto; obj: Pointer; level: Integer; str: PAnsiChar); cdecl;
  procedure SendMessagetoForm(description: string; id: T_mqtt_msg_id; rc: Integer; mosquitto_message: P_mosquitto_message); cdecl;
  //procedure SaveFormBitmapToBMPFile( AForm : TCustomForm; AFileName : string = '' );

var
  frmMain: TfrmMain;

implementation

uses UUtf8;

{$R *.DFM}



// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
procedure TfrmMain.Gather_parameters;
begin


  f_retain := 0;
  f_will_topic := 'will';
  f_will_payload := 'godbye';
  f_will_payload_len := SysUtils.StrLen(PChar(f_will_payload));
  f_user_name := '';
  f_user_password := '';
  f_hostname := 'localhost';
  f_port := 1883;
  f_keepalive := 60;

end;


procedure TfrmMain.FormCreate(Sender: TObject);
var
  res: Integer;
  major: Integer;
  minor: Integer;
  revision: Integer;
begin
  res := mosquitto_lib_init;
  if res <> MOSQ_ERR_SUCCESS then
  begin
    MessageBox(0, PChar('Library initialisation error: ' + IntToStr(res)), PChar('Mosquitto library '), MB_ICONSTOP or MB_OK);
  end;

  mosquitto_lib_version(@major, @minor, @revision);
  caption := 'Mosquitto library ' + IntToStr(major) + '.' + IntToStr(minor) + '.' + IntToStr(revision) + ' test client';

  f_mosq := Nil;
  f_connected := False;
  f_session_started := False;

end;

procedure TfrmMain.Button1Click(Sender: TObject);
var
  res: Integer;
  errdesc: string;
begin

  Gather_session_parameters;
  Start_session;

  if f_connected = True then
    Abort;

  Gather_parameters;

  try
    act_DisconnectExecute(Self);

    mosquitto_will_clear(f_mosq);
    res := mosquitto_will_set(f_mosq, PAnsiChar(f_will_topic), f_will_payload_len, PAnsiChar(f_will_payload), 0, f_retain);

    if res <> MOSQ_ERR_SUCCESS then
    begin
      case res of
        MOSQ_ERR_INVAL:
          errdesc := 'The input parameters is invalid';
        MOSQ_ERR_ERRNO:
          errdesc := 'Connection error';
      else
        errdesc := 'Unknown error';
      end;
      MessageBox(0, PChar('?????? ??????????: ' + errdesc), 'Error', MB_ICONWARNING or MB_OK);
      Screen.Cursor := crDefault;
      Abort;
    end;

    res := mosquitto_username_pw_set(f_mosq, PAnsiChar(f_user_name), PAnsiChar(f_user_password));

    if res <> MOSQ_ERR_SUCCESS then
    begin
      case res of
        MOSQ_ERR_INVAL:
          errdesc := 'The input parameters is invalid';
        MOSQ_ERR_NOMEM:
          errdesc := 'An out of memory condition occurred';
      else
        errdesc := 'Unknown error';
      end;
      MessageBox(0, PChar('Î¸è¡ªà ³ñ² ­î¢ªè •ser name è assword: ' + errdesc), 'Error', MB_ICONWARNING or MB_OK);
      Abort;
    end;

    res := mosquitto_connect(f_mosq, PAnsiChar(f_hostname), f_port, f_keepalive);
    // res := mosquitto_connect_async(f_mosq, f_hostname, f_port, f_keepalive);

    if res <> MOSQ_ERR_SUCCESS then
    begin
      case res of
        MOSQ_ERR_INVAL:
          errdesc := 'The input parameters is invalid';
        MOSQ_ERR_ERRNO:
          errdesc := 'Connection error';
      else
        errdesc := 'Unknown error';
      end;
      MessageBox(0, PChar('Î¸è¡ªà ±î¥¤è­¥òŸ°º ' + errdesc), 'Error', MB_ICONWARNING or MB_OK);
      Screen.Cursor := crDefault;
      Abort;
    end;


    res := mosquitto_loop_start(f_mosq);
    if res <> MOSQ_ERR_SUCCESS then
    begin
      case res of
        MOSQ_ERR_INVAL:
          errdesc := 'The input parameters is invalid';
        MOSQ_ERR_NOT_SUPPORTED:
          errdesc := 'Thread support is not available';
      else
        errdesc := 'Unknown error';
      end;
      MessageBox(0, PChar('?????? ??????????: ' + errdesc), PChar('Error'), MB_ICONWARNING or MB_OK);
      Screen.Cursor := crDefault;
      Abort;
    end;

  finally
         //showmessage('Paso por aqui: ' + inttostr(res) );
  end;


end;

procedure SendMessagetoForm(description: string; id: T_mqtt_msg_id; rc: Integer; mosquitto_message: P_mosquitto_message);
var
  mqttmsg: P_win_message;
begin
  New(mqttmsg);
  mqttmsg^.description := description;
  mqttmsg^.id := id;
  mqttmsg^.rc := rc;
  mqttmsg^.mosquitto_message := mosquitto_message;

  PostMessage(frmMain.Handle, WM_MQTT_MESSAGES, 0, Integer(mqttmsg));
end;


// ------------------------------------------------------------------------------
//
// Callback Parameters:
// mosq - the mosquitto instance making the callback.
// obj - the user data provided in <mosquitto_new>
// rc -  the return code of the connection response, one of:
// 0 - success
// 1 - connection refused (unacceptable protocol version)
// 2 - connection refused (identifier rejected)
// 3 - connection refused (broker unavailable)
// 4-255 - reserved for future use
// ------------------------------------------------------------------------------
procedure Callback_on_connect(mosq: Pmosquitto; obj: Pointer; rc: Integer); cdecl;
begin
  frmMain.f_connect_result := rc;
  if rc = 0 then
  begin
    frmMain.f_connected := True;
  end;
  SendMessagetoForm('Callback_on_connect', ON_CONNECT_ID, rc, Nil);

end;

// ------------------------------------------------------------------------------
// Callback Parameters:
// mosq - the mosquitto instance making the callback.
// obj -  the user data provided in <mosquitto_new>
// rc -   integer value indicating the reason for the disconnect. A value of 0
// means the client has called <mosquitto_disconnect>. Any other value
// indicates that the disconnect is unexpected.
// ------------------------------------------------------------------------------
procedure Callback_on_disconnect(mosq: Pmosquitto; obj: Pointer; rc: Integer); cdecl;
begin
  frmMain.f_disconnect_result := rc;
  frmMain.f_connected := False;
  SendMessagetoForm('Callback_on_disconnect', ON_DISCONNECT_ID, rc, Nil);
end;

// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
procedure Callback_on_publish(mosq: Pmosquitto; obj: Pointer; mid: Integer); cdecl;
begin

  SendMessagetoForm('Callback_on_publish', ON_PUBLISH_ID, mid, Nil);
end;

// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
procedure Callback_on_message(mosq: Pmosquitto; obj: Pointer; mosquitto_message: P_mosquitto_message); cdecl;
var
  dst: P_mosquitto_message;
begin
  dst := AllocMem(SizeOf(T_mosquitto_message));
  // ????????? ?? ????????? mosquitto_message ???? ???????????, ????????? ????? ?? ?????? ?? ???? ????????? ??? ????? ??????????
  mosquitto_message_copy(dst, mosquitto_message);
  SendMessagetoForm('Callback_on_message', ON_MESSAGE_ID, 0, dst);

end;

// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
procedure Callback_on_subscribe(mosq: Pmosquitto; obj: Pointer; mid: Integer; qos_count: Integer; granted_qos: PInteger); cdecl;
begin

  SendMessagetoForm('Callback_on_subscribe', ON_SUBSCRIBE_ID, mid, Nil);
end;

// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
procedure Callback_on_unsubscribe(mosq: Pmosquitto; obj: Pointer; mid: Integer); cdecl;
begin

  SendMessagetoForm('Callback_on_unsubscribe', ON_UNSUBSCRIBE_ID, mid, Nil);
end;

// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
procedure Callback_on_log(mosq: Pmosquitto; obj: Pointer; level: Integer; str: PAnsiChar); cdecl;
var
  msgstr: string;
begin
  msgstr := String(str);
  SendMessagetoForm(msgstr, ON_LOG_ID, Integer(level), Nil);
end;

procedure TfrmMain.Button2Click(Sender: TObject);
var
   res : integer;
  errdesc: string;
begin
     if f_connected = False then
        Abort;

     inc(f_sub_id);

     f_sub_topic := 'avatar/#';
     f_sub_qos := 0;

     res := mosquitto_subscribe(f_mosq, @f_sub_id, PAnsiChar(f_sub_topic), f_sub_qos);
     if res <> MOSQ_ERR_SUCCESS then
     begin
       case res of
         MOSQ_ERR_INVAL:
            errdesc := 'The input parameters is invalid';
         MOSQ_ERR_NOMEM:
            errdesc := 'An out of memory condition occurred';
         MOSQ_ERR_NO_CONN:
            errdesc := 'The client isn''t connected to a broker';
     else
     errdesc := 'Unknown error';
     end;
     MessageBox(0, PChar('Error de tiempo de ejecución de Subsribe: ' + errdesc), 'Error', MB_ICONWARNING or MB_OK);
     Abort;
end;

  res := mosquitto_loop_write(f_mosq, 1);
  if res <> MOSQ_ERR_SUCCESS then
    WriteLog('mosquitto_loop_write = ' + IntToStr(res));

end;


procedure TfrmMain.MessagesgHandler(var Message: TMessage);
var
  mqttmsg: P_win_message;
  logstring: String;
  mosquitto_message: P_mosquitto_message;
  msg: T_received_MQTT_msg;

begin
  mqttmsg := P_win_message(Message.LParam);

  logstring := mqttmsg^.description;

  try
    if mqttmsg^.id <> ON_LOG_ID then
    begin
      Screen.Cursor := crDefault;
    end;

    // ***************************************************** ????????? ?????? ??????????
    // ???? ?? ??????? mosquitto_loop_stop ??? ??????? ??????????, ?? ?? ?????????? ????????? ?????????? ???????????
    if mqttmsg^.id = ON_DISCONNECT_ID then
    begin
      if mqttmsg^.rc <> 0 then
      begin
        // ????????????????? ?????????????
        mosquitto_disconnect(f_mosq);
        mosquitto_loop_stop(f_mosq, 1);
      end
      else
      begin
        mosquitto_loop_stop(f_mosq, 0);
      end;
    end;

    // ***************************************************** ????????? ??????? ??????????
    if mqttmsg^.id = ON_PUBLISH_ID then
    begin
      logstring := logstring + ' mid=' + IntToStr(mqttmsg^.rc);
    end;

    // ***************************************************** ????????? ??????? ????????
    if mqttmsg^.id = ON_SUBSCRIBE_ID then
    begin
      logstring := logstring + ' mid=' + IntToStr(mqttmsg^.rc);
    end;

    // ***************************************************** ????????? ??????? ??????????? ?????????? ?? ???????
    if mqttmsg^.id = ON_MESSAGE_ID then
    begin
       mosquitto_message := mqttmsg^.mosquitto_message;
       ConvertMQTT_msg(mosquitto_message, msg);
       WriteLog(msg.payload);
       mosquitto_message_clear(mosquitto_message);
       FreeMem(mosquitto_message);
    end;


  WriteLog(logstring);
  finally
    Dispose(mqttmsg);
  end;
end;

procedure TfrmMain.WriteLog(logstring: string);
begin
   memo1.lines.add(logstring);
end;

procedure TfrmMain.ConvertMQTT_msg(mosquitto_message: P_mosquitto_message;
  var msg: T_received_MQTT_msg);
var
   tmpstr: string;
begin
  Convert_Topic_To_String(mosquitto_message^.topic, tmpstr);
  msg.topic := tmpstr;
  Convert_Payload_To_String(mosquitto_message^.payload, mosquitto_message^.payloadlen, tmpstr);
  msg.payload := tmpstr;
  msg.mid := mosquitto_message^.mid;
  msg.QoS := mosquitto_message^.QoS;
  msg.retain := boolean(mosquitto_message^.retain);
end;


// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
function TfrmMain.ConvertStringToUTF8(const str: string; var utf8str: AnsiString): Integer;
var
  L, SL: Integer;
begin
  SL := Length(str);
  L := SL * SizeOf(Char);
  L := L + 1;

  SetLength(utf8str, L);
  //UnicodeToUtf8(PAnsiChar(utf8str), L, PWideChar(str), SL);
  //ConvertStringToUTF8 := SysUtils.StrLen(PAnsiChar(utf8str));
  utf8str := AnsiToUtf8(str);
  ConvertStringToUTF8 := SysUtils.StrLen(PAnsiChar(utf8str));
end;

// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
procedure TfrmMain.Convert_Topic_To_String(const utf8str: PAnsiChar; var str: string);
var
  L: Integer;
  Temp: WideString;
begin
  L := StrLen(utf8str);

  str := '';
  if L = 0 then
    Exit;
  SetLength(Temp, L);

  L := Utf8ToUnicode(PWideChar(Temp), L + 1, utf8str, L);
  if L > 0 then
    SetLength(Temp, L - 1)
  else
    Temp := '';
  str := Temp;
end;

// ------------------------------------------------------------------------------
//
// ------------------------------------------------------------------------------
procedure TfrmMain.Convert_Payload_To_String(const utf8str: PAnsiChar; sz: Integer; var str: string);
var
  L: Integer;
  Temp: WideString;
begin
  str := '';
  if sz = 0 then
    Exit;
  SetLength(Temp, sz);

  L := Utf8ToUnicode(PWideChar(Temp), sz + 1, utf8str, sz);
  if L > 0 then
    SetLength(Temp, L - 1)
  else
    Temp := '';
  str := Temp;
end;

procedure TfrmMain.Button3Click(Sender: TObject);
var
   res: integer;
   errdesc : string;
begin
  if f_connected = False then
    Abort;

  try
    inc(f_pub_id);

    f_pub_retain := 1;
    f_pub_qos := 0;
    

  f_pub_topic := 'avatar';

  f_pub_payload_len := ConvertStringToUTF8(edtPayLoad.Text, f_pub_payload);

  // ------------------------------------
  res := mosquitto_publish(f_mosq, @f_pub_id, PAnsiChar(f_pub_topic), f_pub_payload_len, Pointer(f_pub_payload), f_pub_qos, f_pub_retain);
  if res <> MOSQ_ERR_SUCCESS then
  begin
  case res of
	MOSQ_ERR_INVAL:
	  errdesc := 'The input parameters is invalid';
	MOSQ_ERR_NOMEM:
	  errdesc := 'An out of memory condition occurred';
	MOSQ_ERR_NO_CONN:
	  errdesc := 'The client isn''t connected to a broker';
	MOSQ_ERR_PROTOCOL:
	  errdesc := 'There is a protocol error communicating with the broker';
	MOSQ_ERR_PAYLOAD_SIZE:
	  errdesc := 'The payloadlen is too large';
  else
	errdesc := 'Unknown error';
  end;
  MessageBox(0, PChar('Error de tiempo de ejecució® ublish: ' + errdesc), 'Error', MB_ICONWARNING or MB_OK);
  Abort;
  end;

  // ??????????? ?????? ?????  mosquitto_loop_write, ?????  ????????? ?????????? ?? ?????????? ??????? ?????? Ping ?? ???????
  res := mosquitto_loop_write(f_mosq, 1);
  if res <> MOSQ_ERR_SUCCESS then
  begin
    WriteLog('mosquitto_loop_write = ' + IntToStr(res));
  end;
  finally

  end;

end;

procedure TfrmMain.Start_session;
begin
  if f_session_started = True then
  begin
    mosquitto_destroy(f_mosq);
    f_mosq := Nil;
  end;

  f_mosq := mosquitto_new(PAnsiChar(f_user_id), f_clean_session, @f_user_obj);

  if f_mosq = Nil then
  begin
    MessageBox(0, PChar('Error al inicializar la sesión del cliente MQTT'),PChar('Error'), MB_ICONWARNING or MB_OK);
    Abort;
  end;

  mosquitto_connect_callback_set(f_mosq, Callback_on_connect);
  mosquitto_disconnect_callback_set(f_mosq, Callback_on_disconnect);
  mosquitto_publish_callback_set(f_mosq, Callback_on_publish);
  mosquitto_message_callback_set(f_mosq, Callback_on_message);
  mosquitto_subscribe_callback_set(f_mosq, Callback_on_subscribe);
  mosquitto_unsubscribe_callback_set(f_mosq, Callback_on_unsubscribe);
  mosquitto_log_callback_set(f_mosq, Callback_on_log);
  f_session_started := True;
end;

procedure TfrmMain.Gather_session_parameters;
begin
  f_clean_session := 1;
  f_user_id := 'D33A96B9-B618';
end;

procedure TfrmMain.act_DisconnectExecute(Sender: TObject);
var
   res : Integer;
begin
  try
    if f_mosq <> Nil then
    begin
      if f_connected = True then
      begin
        res := mosquitto_disconnect(f_mosq);
        if res <> MOSQ_ERR_SUCCESS then
          WriteLog('mosquitto_disconnect = ' + IntToStr(res));

        res := mosquitto_loop_write(f_mosq, 1);
        if res <> MOSQ_ERR_SUCCESS then
          WriteLog('mosquitto_loop_write = ' + IntToStr(res));
      end;
    end;
  finally
    //UpdateStatusBar;
  end;
end;

procedure TfrmMain.Stop_session;
begin
  if f_mosq <> Nil then
  begin
    if f_connected = True then
    begin
      mosquitto_disconnect(f_mosq);
      mosquitto_loop_stop(f_mosq, 1);
    end;
    mosquitto_destroy(f_mosq);
    f_mosq := Nil;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  Stop_session;
  mosquitto_lib_cleanup;
end;

end.
