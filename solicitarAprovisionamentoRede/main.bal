import ballerina/log;
import ballerinax/java.jms;
import ballerina/http;
import ballerina/io;
import ballerina/os;
import solicitarAprovisionamentoRede.logic;

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowCredentials: true,
        allowMethods: ["POST"]
    }
}
service / on new http:Listener(8080) {
    isolated resource function post solicitarAprovisionamentoRede(@http:Payload xml requestSOM) returns json|xml|error? {
        json|xml response = check logic:requestOrchestration(requestSOM);
        return response;
    }
}
string providerUrl = os:getEnv("INTNOSSIS-JMS-PROVIDER-URL");
string queueName =os:getEnv("INTNOSSIS-JMS-QUEUE-NAME");

service "consumer-service" on new jms:Listener(
    connectionConfig = {
        initialContextFactory: "weblogic.jndi.WLInitialContextFactory",
        providerUrl:providerUrl,
        connectionFactoryName: "CF_RecursoAprovisionamento"
    },
    sessionConfig = {
        acknowledgementMode: "AUTO_ACKNOWLEDGE"
    },
    destination = {
        'type: jms:QUEUE,
        name: queueName
    }
) {
    remote function onMessage(jms:Message message) returns json|xml|error? {
        if message is jms:TextMessage {
            log:printInfo("Text message received", content = message.content);
            io:StringReader reader = new io:StringReader(message.content);
            xml|error? requestSOM = reader.readXml();
            if requestSOM is xml {
                log:printInfo("request que chegou - ", content = requestSOM);
                json|xml response = check logic:requestOrchestration(requestSOM);
                return response;
            } else {
                log:printError("Erro ao converter o xml", requestSOM);
                return requestSOM;
            }
        }
    }
}

