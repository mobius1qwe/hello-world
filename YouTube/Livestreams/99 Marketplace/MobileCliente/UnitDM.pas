unit UnitDM;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.FMXUI.Wait,
  Data.DB, FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, System.IOUtils, REST.Types, REST.Client,
  REST.Authenticator.Basic, Data.Bind.Components, Data.Bind.ObjectScope;

type
  Tdm = class(TDataModule)
    conn: TFDConnection;
    RESTClient: TRESTClient;
    RequestLogin: TRESTRequest;
    HTTPBasicAuthenticator: THTTPBasicAuthenticator;
    RequestLoginCad: TRESTRequest;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  dm: Tdm;

implementation

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

procedure Tdm.DataModuleCreate(Sender: TObject);
begin
    with Conn do
    begin
        {$IFDEF MSWINDOWS}
        if NOT FileExists(System.SysUtils.GetCurrentDir + '\DB\banco.db') then
            raise Exception.Create('Banco de dados n�o encontrado: ' +
                                   System.SysUtils.GetCurrentDir + '\DB\banco.db');

        try
            Params.Values['Database'] := System.SysUtils.GetCurrentDir + '\DB\banco.db';
            Connected := true;
        except on E:Exception do
                raise Exception.Create('Erro de conex�o com o banco de dados: ' + E.Message);
        end;

        {$ELSE}

        Params.Values['DriverID'] := 'SQLite';
        try
            Params.Values['Database'] := TPath.Combine(TPath.GetDocumentsPath, 'banco.db');
            Connected := true;
        except on E:Exception do
            raise Exception.Create('Erro de conex�o com o banco de dados: ' + E.Message);
        end;
        {$ENDIF}
    end;
end;

end.
