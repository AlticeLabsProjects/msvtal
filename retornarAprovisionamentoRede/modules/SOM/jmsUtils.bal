import ballerinax/java.jms;
import ballerina/random;
import ballerina/os;

# Variáveis de configuração da fila JMS do SOM com valores definidos no arquivo "Config.toml".
configurable string[] jmsEndpoints = ?;
configurable string acknowledgementMode = ?;
configurable jms:ConnectionConfiguration connectionConfiguration = ?;

# Função responsável pelo "balanceamento" das requisições para as instancias das filas JMSs.
# + return - String de conexão com a fila JMS.
public isolated function JMSBalancer() returns string|error {
    int arraySize = jmsEndpoints.length();
    int urlPosition = check random:createIntInRange(0, arraySize);
    return jmsEndpoints[urlPosition];
}

# Função responsável por postar a mensagem na fila do SOM.
#
# + request - XML formatado para o request.
# + return - Retorna um erro em caso de problema com a psotagem da mensagem.
public isolated function postMessageSOM(xml request) returns error? {

    string providerUrl = os:getEnv("INTNOSSIS-JMS-PROVIDER-URL");
    string connectionFactoryName = os:getEnv("INTNOSSIS-JMS-CONNECTION-FACTORY");
    string initialContextFactory = "weblogic.jndi.WLInitialContextFactory";
    jms:ConnectionConfiguration test = {initialContextFactory: initialContextFactory, providerUrl: providerUrl, connectionFactoryName: connectionFactoryName};

    jms:Connection connection = check new (test);    
    jms:Session session = check connection->createSession({acknowledgementMode});
    string urlQueue = check JMSBalancer();
    jms:Destination queue = check session->createQueue(urlQueue);
    jms:MessageProducer producer = check session.createProducer(queue);
    jms:TextMessage msg = {
        content: request.toString()
    };
    check producer->send(msg);
}