import ballerina/log;
import ballerinax/oracledb;
import ballerina/sql;
import ballerinax/oracledb.driver as _;
import ballerina/os;
import solicitarInformacoesRede.FFOne;
import solicitarInformacoesRede.NetQ;
import solicitarInformacoesRede.SIS;
import ballerina/regex;
import solicitarInformacoesRede.Logstash;

type QueryResult record {
    string system_target;
};

# Função responsável pela consulta no banco de dados para a obtenção do sistema alvo da orquestração.
#
# + NetQRequest - JSON com os valores obtidos após a extração dos dados do XML recebido do SOM.
# + return - String com o sistema alvo do roteamento, podendo ter três possiveis valores:SIS V2, SIS VTAL, # FFONE.
public isolated function getDataFromDB(json NetQRequest) returns string|error {
    string host = os:getEnv("INTNOSSIS-DB-HOST");
    string username = os:getEnv("INTNOSSIS-DB-USER");
    string password = os:getEnv("INTNOSSIS-DB-PASSWORD");
    string dbName = os:getEnv("INTNOSSIS-DB-NAME");
    string port = os:getEnv("INTNOSSIS-DB-PORT");
    string requestId = check NetQRequest.idNetq;
    string operation = check NetQRequest.operation;
    json parameters = check NetQRequest.parameters;
    string tecnology = parameters.VENDOR is error ? "" : check parameters.VENDOR;
    string line_id = parameters.LINE_ID is error ? "" : check parameters.LINE_ID;
    string lineid = parameters.LINEID is error ? "" : check parameters.LINEID;
    string uf = "";
    if line_id != "" {
        uf = regex:split(line_id, "-")[0];
    } else if lineid != "" {
        uf = regex:split(lineid, "-")[0];
    }
    oracledb:Client dbClient = check new (host, username, password, dbName, check int:fromString(port));
    
    string query = "SELECT system_target from soasis.system_segmentation where operation =" + operation + " AND (tecnology = " + tecnology + " AND uf = " + uf +")`";
    error? dbIntegrationReqLogstash = Logstash:dbIntegrationReqLogstash(host, NetQRequest, null,"BD-REQUEST",query,
     "INVOKE - Consulta - Obtenção do sistema alvo");
    stream<QueryResult, sql:Error?> resultStream = dbClient->query(`SELECT system_target from soasis.system_segmentation where operation = ${operation} AND (tecnology = ${tecnology} AND uf = ${uf})`);
    
    string env = "";
    string queryResult;
    check from QueryResult result in resultStream
        do {
            env = result.system_target;
            queryResult = result.toString();
            
        };
    check resultStream.close();

    error? dbIntegrationReqLogstashResult = Logstash:dbIntegrationReqLogstash(host, NetQRequest,queryResult,"BD-RESPONSE", query,
     "RESPONSE - Response - Sistema alvo");
     if (dbIntegrationReqLogstash is error || dbIntegrationReqLogstashResult is error) {
        log:printError("Erro ao realizar a chamada ao Logstash", dbIntegrationReqLogstashResult);
    }

    if env != "" {
        log:printInfo("Ambiente encontrado - " + env, id = requestId);
        check dbClient.close();
        return env;
    }

    log:printError("Nenhum ambiente foi encontrado com os dados fornecidos. Procurando pelo ambiente padrão para a operação " + operation, id = requestId);
    string operationEnv = ""; 

    query = "SELECT system_target from soasis.system_segmentation where operation = " + operation + " AND (tecnology = '*' AND uf = '*')";
    dbIntegrationReqLogstash = Logstash:dbIntegrationReqLogstash(host, NetQRequest, null,"BD-REQUEST", query,
     "INVOKE - Consulta - Obtenção do sistema alvo padrão");
    stream<QueryResult, sql:Error?> resultStreamOperationDef = dbClient->query(`SELECT system_target from soasis.system_segmentation where operation = ${operation} AND (tecnology = '*' AND uf = '*')`);
    check from QueryResult resultOperationDef in resultStreamOperationDef
        do {
            operationEnv = resultOperationDef.system_target;
            queryResult = resultOperationDef.toString();
        };
    
    check resultStreamOperationDef.close();

    dbIntegrationReqLogstashResult = Logstash:dbIntegrationReqLogstash(host, NetQRequest, queryResult,"BD-RESPONSE",query,
    "RESPONSE - Response - Sistema alvo padrão");
    if (dbIntegrationReqLogstash is error || dbIntegrationReqLogstashResult is error) {
        log:printError("Erro ao realizar a chamada ao Logstash", dbIntegrationReqLogstashResult);
    }

    if operationEnv != "" {
        log:printInfo("Ambiente padrão para a operação encontrado - " + operationEnv, id = requestId);
        check dbClient.close();
        return operationEnv;
    }

    log:printError("Ambiente padrão não encontrado para a operação " + operation + ". Procurando o ambiente default", id = requestId);
    string defaultEnv = "";
    query = "SELECT system_target from soasis.system_segmentation where operation = 'default'";
    dbIntegrationReqLogstash = Logstash:dbIntegrationReqLogstash(host, NetQRequest, null,"BD-REQUEST", query,
     "INVOKE - Consulta - Obtenção do sistema alvo default");

    stream<QueryResult, sql:Error?> resultStreamDefault = dbClient->query(`SELECT system_target from soasis.system_segmentation where operation = 'default'`);
    check from QueryResult resultDefault in resultStreamDefault
        do{
            defaultEnv = resultDefault.system_target;
            queryResult = resultDefault.toString();
        };
    //Failsafe
    if defaultEnv == "" {
        defaultEnv = "SIS V2";
        queryResult = defaultEnv;
    }

    dbIntegrationReqLogstashResult = Logstash:dbIntegrationReqLogstash(host, NetQRequest, queryResult,"BD-RESPONSE","",
    "RESPONSE - Response - Sistema alvo default");
    if (dbIntegrationReqLogstash is error || dbIntegrationReqLogstashResult is error) {
        log:printError("Erro ao realizar a chamada ao Logstash", dbIntegrationReqLogstashResult);
    }

    check resultStreamDefault.close();
    check dbClient.close();
    return defaultEnv;
}

# Função responsável pela realização da orquestração das chamadas.
#
# + NetQRequest - Request XML recebido do NETQ.
# + return - Response JSON recebido após a orquestração.
public isolated function requestOrchestration(xml NetQRequest) returns json|xml|error {
    json|error requestTransformado = NetQ:getDataFromNETQXml(NetQRequest);
    if requestTransformado is error {
        log:printError("Erro ao extrair os dados da requisição do SOM");
        return {"status": "error", "reason": "Erro ao transformar a requisição do SOM"};
    }
    string requestId = check requestTransformado.idNetq;

    string|error sistemaAlvo = getDataFromDB(requestTransformado);
    if sistemaAlvo is error {
        log:printError("Erro ao fazer a query no banco.", sistemaAlvo, id = requestId);
        return sistemaAlvo;
    }
    log:printInfo("Ambiente final - " + sistemaAlvo);
    if sistemaAlvo.toLowerAscii() == "ffone" {
        json|error requestFFOne = FFOne:transformFFOneRequest(requestTransformado);
        if requestFFOne is error {
            log:printError("Erro ao realizar a transformação do request para o FFOne", requestFFOne, id = requestId);
            return requestFFOne;
        }
        xml|error responseFFOne = FFOne:sendRequestFFOne(requestFFOne);
        if responseFFOne is error {
            log:printError("Erro ao realizar a chamada ao FFOne", responseFFOne, id = requestId);
        }
        return responseFFOne;
    }
    else if sistemaAlvo.toLowerAscii() == "sis vtal" {
        json|error requestSISVTal = SIS:transformSISVTalRequest(requestTransformado);
        if requestSISVTal is error {
            log:printError("Erro ao realizar a transformação do request para o SISVTal", requestSISVTal, id = requestId);
            return requestSISVTal;
        }
        xml|error responseSISVTal = SIS:sendRequestSISVTal(requestSISVTal);
        if responseSISVTal is error {
            log:printError("Erro ao realizar a requisição para o SISVTal", responseSISVTal, id = requestId);
        }
        return responseSISVTal;

    }
    else if sistemaAlvo.toLowerAscii() == "sis v2" {
        log:printInfo("Ambiente a ser chamado - SIS V2", id = requestId);
        xml|error responseSISV2 = SIS:sendRequestSISV2(NetQRequest);
        return responseSISV2;
    }
}
