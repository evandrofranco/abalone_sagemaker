# Exemplo de utilização do Sage Maker na AWS

Este projeto é um exemplo de como utilizar o Sage Maker na AWS. Criando um modelo em R e posteriormente acessando o endpoint gerado através de código Python.

## Pré Requisito

Foi utilizado o Cloud Formation abaixo para criar uma máquina com o R Studio e as respectivas dependências:
	
	[rstudio_sagemaker.yaml](https://s3.amazonaws.com/aws-ml-blog/artifacts/build-sagemaker-models-with-r/rstudio_sagemaker.yaml)
	
## R Studio

Após a criação da máquina EC2 com o RStudio, basta acessá-la no endereço:
	
	http://IP-PUBLICO:8787
	
Feito isto, copiar o código do arquivo **exemplo.R** e ir executando passo a passo, sendo que é necessário substiutir o trecho abaixo:

	- Substituir trecho de código abaixo pela role criada com permissão no Sage Maker e S3:
		role_arn <- session$expand_role('<nome-da-role>')
		
# Notebook

Criar uma instância de Notebook na AWS (na guia Sage Maker)

Copiar o código do arquivo **Call_API.py** para um notebook do tipo **conda_python3**.

Substituir valores (no código):
	
	- Endpoint criado no exemplo em R (endereço para acesso da API):
		ENDPOINT_NAME = '<nome-do-endpoint>'
	- Região (se necessário e api estiver em outra região diferente do notebook):
		runtime= boto3.client('runtime.sagemaker', region_name='<region>')
	- Nome do Bucket S3:
		bucket='<s3-bucket-name>'
	- Nome do arquivo do S3 com o prefixo (caminho de diretórios até chegar no arquivo):
		data_key = '<prefix>/<file-name.csv>'