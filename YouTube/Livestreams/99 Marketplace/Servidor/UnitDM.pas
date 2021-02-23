unit UnitDM;

interface

uses
  System.SysUtils, System.Classes, uDWDataModule, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.FMXUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.Phys.FBDef, uDWAbout, uRESTDWServerEvents, uDWJSONObject,
  System.JSON, FireDAC.DApt, uDWConsts, FMX.Graphics, uFunctions;

type
  Tdm = class(TServerMethodDataModule)
    conn: TFDConnection;
    DWEventsUsuario: TDWServerEvents;
    DWEventsPedido: TDWServerEvents;
    DWEventsNotificacao: TDWServerEvents;
    DWEventsCategoria: TDWServerEvents;
    DWEventsOrcamento: TDWServerEvents;
    procedure DWEventsEventshoraReplyEvent(var Params: TDWParams;
      var Result: string);
    procedure DWEventsEventsusuarioReplyEventByType(var Params: TDWParams;
      var Result: string; const RequestType: TRequestType;
      var StatusCode: Integer; RequestHeader: TStringList);
    procedure DWEventsPedidoEventspedidoReplyEventByType(var Params: TDWParams;
      var Result: string; const RequestType: TRequestType;
      var StatusCode: Integer; RequestHeader: TStringList);
    procedure DWEventsNotificacaoEventsnotificacaoReplyEventByType(
      var Params: TDWParams; var Result: string;
      const RequestType: TRequestType; var StatusCode: Integer;
      RequestHeader: TStringList);
    procedure DWEventsCategoriaEventscategoriaReplyEventByType(
      var Params: TDWParams; var Result: string;
      const RequestType: TRequestType; var StatusCode: Integer;
      RequestHeader: TStringList);
    procedure DWEventsCategoriaEventsgrupoReplyEventByType(
      var Params: TDWParams; var Result: string;
      const RequestType: TRequestType; var StatusCode: Integer;
      RequestHeader: TStringList);
    procedure DWServerEvents1EventsorcamentoReplyEventByType(
      var Params: TDWParams; var Result: string;
      const RequestType: TRequestType; var StatusCode: Integer;
      RequestHeader: TStringList);
  private
    function ValidarLogin(email, senha: string;
                          out status: integer): string;
    function CriarUsuario(email, senha, nome, fone, foto64: string;
      out status: integer): string;
    function ListaPedidos(sts, id_usuario: string;
      out status_code: integer): string;
    function ListaNotificacoes(id_usuario: string;
      out status_code: integer): string;
    function ExcluirNotificacao(id_usuario, id_notificacao: string;
      out status: integer): string;
    function CriarPedido(id_usuario, categoria, grupo, endereco, dt_servico,
      detalhe, qtd_max_orc: string; out status: integer): string;
    function EditarPedido(id_pedido, categoria, grupo, endereco,
                          dt_servico, detalhe : string;
                          out status: integer): string;
    function ExcluirPedido(id_usuario, id_pedido: string;
      out status: integer): string;
    function ListaOrcamentos(id_pedido: string;
      out status_code: integer): string;
    function CriarOrcamento(id_pedido, id_usuario, obs: string;
      valor_total: double; out status: integer): string;
    function DadosPedido(id_pedido: string; out status: integer): string;
    function ListaCategorias(out status_code: integer): string;
    function ListaGrupos(categoria: string; out status_code: integer): string;

    { Private declarations }
  public
    { Public declarations }
    function CarregarConfig: string;
  end;

var
  dm: Tdm;

implementation

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

uses System.IniFiles, cUsuario, cPedido, cNotificacao, cPedidoOrcamento,
     cCategoria;

function TDm.CarregarConfig(): string;
var
    arq_ini : string;
    ini : TIniFile;
begin
    try
        arq_ini := System.SysUtils.GetCurrentDir + '\servidor.ini';

        // Verifica se INI existe...
        if NOT FileExists(arq_ini) then
        begin
            Result := 'Arquivo INI n�o encontrado: ' + arq_ini;
            exit;
        end;

        // Instanciar arquivo INI...
        ini := TIniFile.Create(arq_ini);

        // Buscar dados do arquivo fisico...
        dm.conn.Params.Values['DriverID'] := ini.ReadString('Banco de Dados', 'DriverID', '');
        dm.conn.Params.Values['Database'] := ini.ReadString('Banco de Dados', 'Database', '');
        dm.conn.Params.Values['User_name'] := ini.ReadString('Banco de Dados', 'User_name', '');
        dm.conn.Params.Values['Password'] := ini.ReadString('Banco de Dados', 'Password', '');

        try
            conn.Connected := true;
            Result := 'OK';
        except on ex:exception do
            Result := 'Erro ao acessar o banco: ' + ex.Message;
        end;

    finally
        if Assigned(ini) then
            ini.DisposeOf;
    end;
end;

procedure Tdm.DWEventsEventshoraReplyEvent(var Params: TDWParams;
  var Result: string);
begin
    Result := '{"data":"' + FormatDateTime('dd/mm/yyyy hh:nn', now) +  '"}';
end;


function TDm.ValidarLogin(email, senha: string;
                          out status: integer): string;
var
    u : TUsuario;
    json : TJSONObject;
    erro: string;
begin
    try
        u := TUsuario.Create(dm.conn);
        u.EMAIL := email;
        u.SENHA := senha;

        json := TJSONObject.Create;

        // {"retorno":"OK", "id_usuario": 123, "nome": "Heber...."}
        // {"retorno":"Erro xyz....", "id_usuario": 0, "nome": ""}
        if NOT u.ValidarLogin(erro) then
        begin
            json.AddPair('retorno', erro);
            json.AddPair('id_usuario', '0');
            json.AddPair('nome', '');
            Status := 401;
        end
        else
        begin
            json.AddPair('retorno', 'OK');
            json.AddPair('id_usuario', u.ID_USUARIO.ToString);
            json.AddPair('nome', u.NOME);
            Status := 200;
        end;

        Result := json.ToString;

    finally
        json.DisposeOf;
        u.DisposeOf;
    end;
end;

function TDm.CriarUsuario(email, senha, nome, fone, foto64 : string;
                          out status: integer): string;
var
    u : TUsuario;
    json : TJSONObject;
    erro: string;
    foto_bmp : TBitmap;
begin
    try
        json := TJSONObject.Create;
        u := TUsuario.Create(dm.conn);


        if foto64 = '' then
        begin
            json.AddPair('retorno', 'Foto do usu�rio n�o enviada');
            json.AddPair('id_usuario', '0');
            json.AddPair('nome', '');
            Status := 400;
            Result := json.ToString;
            exit;
        end;

        // Criar foto bitmap...
        try
            foto_bmp := TFunctions.BitmapFromBase64(foto64);
        except on ex:exception do
            begin
                json.AddPair('retorno', 'Erro ao criar imagem no servidor: ' + ex.Message);
                json.AddPair('id_usuario', '0');
                json.AddPair('nome', '');
                Status := 400;
                Result := json.ToString;
                exit;
            end;
        end;


        u.ID_USUARIO := 0;
        u.EMAIL := email;
        u.SENHA := senha;
        u.NOME := nome;
        u.FONE := fone;
        u.FOTO := foto_bmp;

        // Validar se usuario existe...
        if u.DadosUsuario(erro) then
        begin
            json.AddPair('retorno', 'J� existe um usu�rio com esse email');
            json.AddPair('id_usuario', '0');
            json.AddPair('nome', '');
            Status := 400;
            Result := json.ToString;
            exit;
        end;

        if NOT u.Inserir(erro) then
        begin
            json.AddPair('retorno', erro);
            json.AddPair('id_usuario', '0');
            json.AddPair('nome', '');
            Status := 400;
        end
        else
        begin
            json.AddPair('retorno', 'OK');
            json.AddPair('id_usuario', u.ID_USUARIO.ToString);
            json.AddPair('nome', u.NOME);
            Status := 201;
        end;

        Result := json.ToString;

    finally
        foto_bmp.DisposeOf;
        json.DisposeOf;
        u.DisposeOf;
    end;
end;


function TDm.CriarPedido(id_usuario, categoria, grupo, endereco,
                         dt_servico, detalhe, qtd_max_orc: string;
                         out status: integer): string;
var
    p : TPedido;
    json : TJSONObject;
    erro: string;
begin
    try
        json := TJSONObject.Create;
        p := TPedido.Create(dm.conn);


        // Valida��es dos parametros...
        if (id_usuario = '') or (categoria = '') or (grupo = '') or (endereco = '') or
           (dt_servico = '') or (detalhe = '') or (qtd_max_orc = '') then
        begin
            json.AddPair('retorno', 'Informe todos os par�metros');
            json.AddPair('id_pedido', '0');
            Status := 400;
            Result := json.ToString;
            exit;
        end;


        try
            StrToInt(id_usuario);
        except
            json.AddPair('retorno', 'Id. usu�rio inv�lido');
            json.AddPair('id_pedido', '0');
            Status := 400;
            Result := json.ToString;
            exit;
        end;

        try
            StrToInt(qtd_max_orc);
        except
            json.AddPair('retorno', 'Qtd. de or�amentos inv�lida');
            json.AddPair('id_pedido', '0');
            Status := 400;
            Result := json.ToString;
            exit;
        end;

        p.ID_USUARIO := id_usuario.ToInteger;
        p.STATUS := 'P'; // P=Pendente / A=Aceito / R=Realizado
        p.CATEGORIA := categoria;
        p.GRUPO := grupo;
        p.ENDERECO := endereco;
        p.DT_SERVICO := TFunctions.StrToData(dt_servico, 'dd/mm/yyyy hh:nn:ss');
        p.DETALHE := detalhe;
        p.QTD_MAX_ORC := qtd_max_orc.ToInteger;
        p.VALOR_TOTAL := 0;


        if NOT p.Inserir(erro) then
        begin
            json.AddPair('retorno', erro);
            json.AddPair('id_pedido', '0');
            Status := 400;
        end
        else
        begin
            json.AddPair('retorno', 'OK');
            json.AddPair('id_pedido', p.ID_PEDIDO.ToString);
            Status := 201;
        end;

        Result := json.ToString;

    finally
        json.DisposeOf;
        p.DisposeOf;
    end;
end;

function TDm.CriarOrcamento(id_pedido, id_usuario, obs: string;
                            valor_total : double;
                            out status: integer): string;
var
    o : TPedidoOrcamento;
    json : TJSONObject;
    erro: string;
begin
    try
        json := TJSONObject.Create;
        o := TPedidoOrcamento.Create(dm.conn);


        // Valida��es dos parametros...
        if (id_usuario = '') or (id_pedido = '') or (obs = '') then
        begin
            json.AddPair('retorno', 'Informe todos os par�metros');
            json.AddPair('id_orcamento', '0');
            Status := 400;
            Result := json.ToString;
            exit;
        end;


        try
            StrToInt(id_pedido);
        except
            json.AddPair('retorno', 'Id. pedido inv�lido');
            json.AddPair('id_orcamento', '0');
            Status := 400;
            Result := json.ToString;
            exit;
        end;

        try
            StrToInt(id_usuario);
        except
            json.AddPair('retorno', 'Id. usu�rio inv�lido');
            json.AddPair('id_orcamento', '0');
            Status := 400;
            Result := json.ToString;
            exit;
        end;

        o.ID_PEDIDO := id_pedido.ToInteger;
        o.ID_USUARIO := id_usuario.ToInteger;
        o.VALOR_TOTAL := valor_total;
        o.OBS := obs;
        o.STATUS := 'A';

        if NOT o.Inserir(erro) then
        begin
            json.AddPair('retorno', erro);
            json.AddPair('id_orcamento', '0');
            Status := 400;
        end
        else
        begin
            json.AddPair('retorno', 'OK');
            json.AddPair('id_orcamento', o.ID_ORCAMENTO.ToString);
            Status := 201;
        end;

        Result := json.ToString;

    finally
        json.DisposeOf;
        o.DisposeOf;
    end;
end;


function TDm.EditarPedido(id_pedido, categoria, grupo, endereco,
                          dt_servico, detalhe : string;
                          out status: integer): string;
var
    p : TPedido;
    json : TJSONObject;
    erro: string;
begin
    try
        json := TJSONObject.Create;
        p := TPedido.Create(dm.conn);

        // Valida��es dos parametros...
        if (id_pedido = '') or (categoria = '') or (grupo = '') or
           (endereco = '') or (dt_servico = '') or (detalhe = '') then
        begin
            json.AddPair('retorno', 'Informe todos os par�metros');
            json.AddPair('id_pedido', '0');
            Status := 400;
            Result := json.ToString;
            exit;
        end;

        try
            StrToInt(id_pedido);
        except
            json.AddPair('retorno', 'Id. pedido inv�lido');
            json.AddPair('id_pedido', '0');
            Status := 400;
            Result := json.ToString;
            exit;
        end;


        p.ID_PEDIDO := id_pedido.ToInteger;
        p.CATEGORIA := categoria;
        p.GRUPO := grupo;
        p.ENDERECO := endereco;
        p.DT_SERVICO := TFunctions.StrToData(dt_servico, 'dd/mm/yyyy hh:nn:ss');
        p.DETALHE := detalhe;

        if NOT p.Editar(erro) then
        begin
            json.AddPair('retorno', erro);
            json.AddPair('id_pedido', p.ID_PEDIDO.ToString);
            Status := 400;
        end
        else
        begin
            json.AddPair('retorno', 'OK');
            json.AddPair('id_pedido', p.ID_PEDIDO.ToString);
            Status := 200;
        end;

        Result := json.ToString;

    finally
        json.DisposeOf;
        p.DisposeOf;
    end;
end;

function TDm.ExcluirPedido(id_usuario, id_pedido: string;
                           out status: integer): string;
var
    p : TPedido;
    json : TJSONObject;
    erro: string;
begin
    try
        json := TJSONObject.Create;
        p := TPedido.Create(dm.conn);

        try
            p.ID_PEDIDO := id_pedido.ToInteger;
            p.ID_USUARIO := id_usuario.ToInteger;

            if NOT p.Excluir(erro) then
            begin
                json.AddPair('retorno', erro);
                Status := 400;
            end
            else
            begin
                json.AddPair('retorno', 'OK');
                Status := 200;
            end;
        except on ex:exception do
            begin
                json.AddPair('retorno', ex.Message);
                Status := 400;
            end;
        end;

        Result := json.ToString;

    finally
        json.DisposeOf;
        p.DisposeOf;
    end;
end;

function TDm.ExcluirNotificacao(id_usuario, id_notificacao : string;
                                out status: integer): string;
var
    n : TNotificacao;
    json : TJSONObject;
    erro: string;
begin
    try
        json := TJSONObject.Create;
        n := TNotificacao.Create(dm.conn);

        try
            n.ID_USUARIO_PARA := id_usuario.ToInteger;
            n.ID_NOTIFICACAO := id_notificacao.ToInteger;

            if NOT n.Excluir(erro) then
            begin
                json.AddPair('retorno', erro);
                Status := 400;
            end
            else
            begin
                json.AddPair('retorno', 'OK');
                Status := 202;
            end;
        except on ex:exception do
            begin
                json.AddPair('retorno', ex.Message);
                Status := 400;
            end;
        end;

        Result := json.ToString;

    finally
        json.DisposeOf;
        n.DisposeOf;
    end;
end;

function TDm.ListaOrcamentos(id_pedido: string;
                             out status_code: integer): string;
var
    o : TPedidoOrcamento;
    json : uDWJSONObject.TJSONValue;
    qry : TFDQuery;
    erro: string;
begin
    try
        o := TPedidoOrcamento.Create(dm.conn);
        o.ID_PEDIDO := id_pedido.ToInteger;

        qry := o.ListarOrcamento('', erro);

        json := uDWJSONObject.TJSONValue.Create;
        json.LoadFromDataset('', qry, false, jmPureJSON, 'dd/mm/yyyy hh:nn:ss');

        Result := json.ToJSON;
        status_code := 200;

    finally
        json.DisposeOf;
        o.DisposeOf;
    end;
end;

function TDm.ListaCategorias(out status_code: integer): string;
var
    c : TCategoria;
    json : uDWJSONObject.TJSONValue;
    qry : TFDQuery;
    erro: string;
begin
    try
        try
            c := TCategoria.Create(dm.conn);
            qry := c.ListarCategoria('', erro);

            json := uDWJSONObject.TJSONValue.Create;
            json.LoadFromDataset('', qry, false, jmPureJSON, 'dd/mm/yy hh:nn');

            Result := json.ToJSON;
            status_code := 200;
        except on ex:exception do
            begin
                status_code := 400;
                Result := '[{"retorno": "' + ex.Message + '"}]';
            end;
        end;

    finally
        json.DisposeOf;
        c.DisposeOf;
    end;
end;

function TDm.ListaGrupos(categoria : string;
                         out status_code: integer): string;
var
    c : TCategoria;
    json : uDWJSONObject.TJSONValue;
    qry : TFDQuery;
    erro: string;
begin
    try
        try
            c := TCategoria.Create(dm.conn);
            c.CATEGORIA := categoria;
            qry := c.ListarGrupo('', erro);

            json := uDWJSONObject.TJSONValue.Create;
            json.LoadFromDataset('', qry, false, jmPureJSON, 'dd/mm/yy hh:nn');

            Result := json.ToJSON;
            status_code := 200;
        except on ex:exception do
            begin
                status_code := 400;
                Result := '[{"retorno": "' + ex.Message + '"}]';
            end;
        end;

    finally
        json.DisposeOf;
        c.DisposeOf;
    end;
end;

function TDm.ListaPedidos(sts, id_usuario: string;
                          out status_code: integer): string;
var
    p : TPedido;
    json : uDWJSONObject.TJSONValue;
    qry : TFDQuery;
    erro: string;
begin
    try
        p := TPedido.Create(dm.conn);
        p.STATUS := sts;
        p.ID_USUARIO := id_usuario.ToInteger;

        qry := p.ListarPedido('', erro);

        json := uDWJSONObject.TJSONValue.Create;
        json.LoadFromDataset('', qry, false, jmPureJSON, 'dd/mm/yyyy hh:nn:ss');

        Result := json.ToJSON;
        status_code := 200;

    finally
        json.DisposeOf;
        p.DisposeOf;
    end;
end;


function TDm.DadosPedido(id_pedido: string;
                         out status: integer): string;
var
    p : TPedido;
    json : TJSONObject;
    erro: string;
begin
    try
        sleep(2000);
        json := TJSONObject.Create;
        p := TPedido.Create(dm.conn);


        try
            id_pedido.ToInteger;
        except
            json.AddPair('retorno', 'Id. pedido inv�lido');
            Status := 401;
            exit;
        end;


        p.ID_PEDIDO := id_pedido.ToInteger;

        if NOT p.DadosPedido(erro) then
        begin
            json.AddPair('retorno', erro);
            Status := 401;
        end
        else
        begin
            json.AddPair('retorno', 'OK');
            json.AddPair('id_pedido', p.ID_PEDIDO.ToString);
            json.AddPair('id_usuario', p.ID_USUARIO.ToString);
            json.AddPair('status', p.STATUS);
            json.AddPair('categoria', p.CATEGORIA);
            json.AddPair('grupo', p.GRUPO);
            json.AddPair('endereco', p.ENDERECO);
            json.AddPair('dt_geracao', FormatDateTime('DD/MM/YYYY HH:NN:SS', p.DT_GERACAO));
            json.AddPair('dt_servico', FormatDateTime('DD/MM/YYYY HH:NN:SS', p.DT_SERVICO));
            json.AddPair('detalhe', p.DETALHE);
            json.AddPair('qtd_max_orc', TJSONNumber.Create(p.QTD_MAX_ORC));
            json.AddPair('valor_total', TJSONNumber.Create(p.VALOR_TOTAL));
            Status := 200;
        end;

        Result := json.ToString;

    finally
        json.DisposeOf;
        p.DisposeOf;
    end;
end;


function TDm.ListaNotificacoes(id_usuario: string;
                          out status_code: integer): string;
var
    n : TNotificacao;
    json : uDWJSONObject.TJSONValue;
    qry : TFDQuery;
    erro: string;
begin
    try
        try
            n := TNotificacao.Create(dm.conn);
            n.ID_USUARIO_PARA := id_usuario.ToInteger;

            qry := n.ListarNotificacao('', erro);

            json := uDWJSONObject.TJSONValue.Create;
            json.LoadFromDataset('', qry, false, jmPureJSON, 'dd/mm/yy hh:nn');

            Result := json.ToJSON;
            status_code := 200;
        except on ex:exception do
            begin
                status_code := 400;
                Result := '[{"retorno": "' + ex.Message + '"}]';
            end;
        end;

    finally
        json.DisposeOf;
        n.DisposeOf;
    end;
end;

procedure Tdm.DWEventsCategoriaEventscategoriaReplyEventByType(
  var Params: TDWParams; var Result: string; const RequestType: TRequestType;
  var StatusCode: Integer; RequestHeader: TStringList);
begin
    // GET.......
    if RequestType = TRequestType.rtGet then
        Result := ListaCategorias(StatusCode);
end;

procedure Tdm.DWEventsCategoriaEventsgrupoReplyEventByType(
  var Params: TDWParams; var Result: string; const RequestType: TRequestType;
  var StatusCode: Integer; RequestHeader: TStringList);
begin
    // GET.......
    if RequestType = TRequestType.rtGet then
        Result := ListaGrupos(Params.ItemsString['categoria'].AsString,
                              StatusCode);
end;


procedure Tdm.DWEventsEventsusuarioReplyEventByType(var Params: TDWParams;
  var Result: string; const RequestType: TRequestType; var StatusCode: Integer;
  RequestHeader: TStringList);
begin
    // GET.......
    if RequestType = TRequestType.rtGet then
        Result := ValidarLogin(Params.ItemsString['email'].AsString,
                               Params.ItemsString['senha'].AsString,
                               StatusCode)
    else
    // POST.......
    if RequestType = TRequestType.rtPost then
        Result := CriarUsuario(Params.ItemsString['email'].AsString,
                               Params.ItemsString['senha'].AsString,
                               Params.ItemsString['nome'].AsString,
                               Params.ItemsString['fone'].AsString,
                               Params.ItemsString['foto'].AsString,
                               StatusCode)
    else
    begin
        StatusCode := 403;
        Result := '{"retorno":"Verbo HTTP n�o � v�lido. Utilize o GET", "id_usuario": 0, "nome": ""}';
    end;

end;

procedure Tdm.DWEventsNotificacaoEventsnotificacaoReplyEventByType(
  var Params: TDWParams; var Result: string; const RequestType: TRequestType;
  var StatusCode: Integer; RequestHeader: TStringList);
begin
    // GET.......
    if RequestType = TRequestType.rtGet then
        Result := ListaNotificacoes(Params.ItemsString['id_usuario'].AsString,
                               StatusCode)
    else
    // DELETE.......
    if RequestType = TRequestType.rtDelete then
        Result := ExcluirNotificacao(Params.ItemsString['id_usuario'].AsString,
                                     Params.ItemsString['id_notificacao'].AsString,
                                     StatusCode)
    {
    else
    // POST.......
    if RequestType = TRequestType.rtPost then
        Result := CriarUsuario(Params.ItemsString['email'].AsString,
                               Params.ItemsString['senha'].AsString,
                               Params.ItemsString['nome'].AsString,
                               Params.ItemsString['fone'].AsString,
                               Params.ItemsString['foto'].AsString,
                               StatusCode)
    }
    else
    begin
        StatusCode := 403;
        Result := '{"retorno":"Verbo HTTP n�o � v�lido. Utilize o GET", "id_usuario": 0, "nome": ""}';
    end;
end;

procedure Tdm.DWEventsPedidoEventspedidoReplyEventByType(var Params: TDWParams;
  var Result: string; const RequestType: TRequestType; var StatusCode: Integer;
  RequestHeader: TStringList);
var
    uri_param : string;
begin
    try
        uri_param := Params.ItemsString['0'].AsString;
    except
        uri_param := '';
    end;

    // GET (LISTAGEM).......
    if (RequestType = TRequestType.rtGet) and (uri_param = '')  then
        Result := ListaPedidos(Params.ItemsString['status'].AsString,
                               Params.ItemsString['id_usuario'].AsString,
                               StatusCode)

    else
    // GET (DETALHES PEDIDO).......
    if (RequestType = TRequestType.rtGet) and (uri_param <> '')  then
        Result := DadosPedido(uri_param, StatusCode)
    else
    // POST.......
    if RequestType = TRequestType.rtPost then
        Result := CriarPedido(Params.ItemsString['id_usuario'].AsString,
                              Params.ItemsString['categoria'].AsString,
                              Params.ItemsString['grupo'].AsString,
                              Params.ItemsString['endereco'].AsString,
                              Params.ItemsString['dt_servico'].AsString, // yyyy-mm-dd hh:nn:ss
                              Params.ItemsString['detalhe'].AsString,
                              Params.ItemsString['qtd_max_orc'].AsString,
                              StatusCode)

    else
    // PATCH.......
    if RequestType = TRequestType.rtPatch then
        Result := EditarPedido(Params.ItemsString['id_pedido'].AsString,
                              Params.ItemsString['categoria'].AsString,
                              Params.ItemsString['grupo'].AsString,
                              Params.ItemsString['endereco'].AsString,
                              Params.ItemsString['dt_servico'].AsString,
                              Params.ItemsString['detalhe'].AsString,
                              StatusCode)

    else
    // DELETE.......
    if RequestType = TRequestType.rtDelete then
        Result := ExcluirPedido(Params.ItemsString['id_usuario'].AsString,
                                Params.ItemsString['id_pedido'].AsString,
                                StatusCode)
    else
    begin
        StatusCode := 403;
        Result := '{"retorno":"Verbo HTTP n�o � v�lido.", "id_pedido": 0}';
    end;
end;

procedure Tdm.DWServerEvents1EventsorcamentoReplyEventByType(
  var Params: TDWParams; var Result: string; const RequestType: TRequestType;
  var StatusCode: Integer; RequestHeader: TStringList);
begin
    // GET.......
    if RequestType = TRequestType.rtGet then
        Result := ListaOrcamentos(Params.ItemsString['id_pedido'].AsString,
                                  StatusCode)
    else
    // POST.......
    if RequestType = TRequestType.rtPost then
        Result := CriarOrcamento(Params.ItemsString['id_pedido'].AsString,
                              Params.ItemsString['id_usuario'].AsString,
                              Params.ItemsString['obs'].AsString,
                              Params.ItemsString['valor_total'].AsFloat / 100,
                              StatusCode)
    {
    else
    // PATCH.......
    if RequestType = TRequestType.rtPatch then
        Result := EditarPedido(Params.ItemsString['id_pedido'].AsString,
                              Params.ItemsString['categoria'].AsString,
                              Params.ItemsString['grupo'].AsString,
                              Params.ItemsString['endereco'].AsString,
                              Params.ItemsString['dt_servico'].AsString,
                              Params.ItemsString['detalhe'].AsString,
                              StatusCode)

    else
    // DELETE.......
    if RequestType = TRequestType.rtDelete then
        Result := ExcluirPedido(Params.ItemsString['id_usuario'].AsString,
                                Params.ItemsString['id_pedido'].AsString,
                                StatusCode)
    }
    else
    begin
        StatusCode := 403;
        Result := '{"retorno":"Verbo HTTP n�o � v�lido.", "id_pedido": 0}';
    end;
end;

end.
