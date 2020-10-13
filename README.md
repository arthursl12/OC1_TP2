# OC1_TP2

## Integrantes
Arthur Souto Lima - 2018055113

## Problema 4 - Load With Increment
Para implementar essa intrução bastou mudar a unidade de controle. 

## Problema 6 - Store Sum
A implementação dessa instrução exigiu três novos bits de controle, que são 0 para as demais instruções e 
1 para store sum. Eles são descritos a seguir:

1. Definir a entrada 1 da ALU para que seja o imediato e não o conteúdo do registrador 1
2. Definir a entrada do endereço de memória a ser acessado para que seja o conteúdo do registrador 1
e não a saída da ALU
3. Definir o dado a ser escrito para ser a saída da ALU e não o conteúdo do registrador 2

A maior dificuldade encontrada nessa implementação foi encontrar uma forma de mudar quem a memória 
usaria como endereço. 

Para codificação da instrução em si, considerando que ela não existe no RISC-V padrão, pegou-se a formatação da instrução
de store, que possui dois campos de registrador de origem e um campo para o imediato. 
O funct7 (opcode) escolhido foi 1110011, que é o do ADD com um 1 no primeiro dígito. Esse funct7 não define 
quaisquer funções do TP ou do datapath então isso facilita a implementação, já que evita conflitos. 
O funct3 é 000, apesar de ele não ser relevante para a decodificação da instrução. 

![Formatação Instrução](https://i.imgur.com/KB3Ec2l.png)



## Problema 7 - BLT
A ideia da implementação foi uma adaptação do BEQ que já estava implementado. Criou-se uma flag 
partindo da ALU para o módulo de fetch que indicava se o conteúdo do primeiro registrador era 
menor que a do segundo e uma outra flag de controle que discriminava para o fetch que era uma 
instrução de branch quando menor que e não quando igual. Além disso, adicionamos uma condição 
"ou" na seção em que o offset seria somado ao PC. Agora, faremos isso quando ou estivéssemos 
com a flag de BEQ e de zero ativas ou estivéssemos com a flag de BLT e de menor ativas.


## Problema 8 - BGE
Com a instrução BLT implementada, a BGE já estava praticamente pronta: bastou criar uma flag para 
o módulo de fetch avisando que era um branch de "maior que" e adicionar uma condição para 
incrementar o PC utilizando a negação do flag de resultado negativo da instrução BLT. Para que 
o igual também fizesse o branch, no módulo de controle, ao identificarmos essa instrução BGE, 
ativamos também a flag de branch on equal, além da recém criada flag de branch quando maior.
