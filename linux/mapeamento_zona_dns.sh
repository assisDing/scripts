#!/usr/bin/env bash

clear

echo "=============================================="
echo "        COLETA COMPLETA DE INFORMACOES DNS"
echo "                  UTILIZANDO DIG"
echo "=============================================="
echo

# Verifica se o dig está instalado
if ! command -v dig >/dev/null 2>&1; then
    echo "[-] O comando dig não está instalado."

    if command -v apt >/dev/null 2>&1; then
        echo "[+] Instale com:"
        echo "    sudo apt update && sudo apt install dnsutils"
    fi

    exit 1
fi

read -rp "[?] Digite o domínio ou site, por exemplo exemplo.com: " DOMAIN

# Remove espaços e elementos desnecessários
DOMAIN="$(echo "$DOMAIN" | tr -d '[:space:]')"
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"
DOMAIN="${DOMAIN%%\?*}"
DOMAIN="${DOMAIN%%\#*}"

if [[ -z "$DOMAIN" || "$DOMAIN" != *.* ]]; then
    echo
    echo "[-] Domínio inválido."
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT="relatorio_dig_${DOMAIN}_${TIMESTAMP}.txt"

# Executa o comando, mostra na tela e salva no arquivo
run_query() {
    echo
    echo "================================================================"
    echo "[+] $1"
    echo "================================================================"
    echo "[+] Comando: $2"
    echo

    eval "$2"

    STATUS=$?

    echo
    if [[ $STATUS -eq 0 ]]; then
        echo "[+] Consulta finalizada."
    else
        echo "[-] Consulta finalizada com código de saída: $STATUS"
    fi
}

# Tudo dentro deste bloco aparece na tela e é salvo no arquivo
{
    echo "================================================================"
    echo "RELATÓRIO COMPLETO DE DNS"
    echo "================================================================"
    echo "Domínio: $DOMAIN"
    echo "Data: $(date)"
    echo "Host local: $(hostname)"
    echo "Arquivo: $OUTPUT"
    echo "================================================================"
    echo

    run_query "Consulta DNS padrão" \
        "dig '$DOMAIN'"

    run_query "Registros A - endereços IPv4" \
        "dig '$DOMAIN' A"

    run_query "Registros AAAA - endereços IPv6" \
        "dig '$DOMAIN' AAAA"

    run_query "Registros CNAME - aliases" \
        "dig '$DOMAIN' CNAME"

    run_query "Registros NS - servidores autoritativos" \
        "dig '$DOMAIN' NS"

    run_query "Registros MX - servidores de e-mail" \
        "dig '$DOMAIN' MX"

    run_query "Registros TXT" \
        "dig '$DOMAIN' TXT"

    run_query "Registros SPF" \
        "dig '$DOMAIN' SPF"

    run_query "Registros SOA - autoridade da zona" \
        "dig '$DOMAIN' SOA"

    run_query "Registros CAA - autoridades certificadoras" \
        "dig '$DOMAIN' CAA"

    run_query "Registros SRV - serviços publicados" \
        "dig '$DOMAIN' SRV"

    run_query "Registros NAPTR" \
        "dig '$DOMAIN' NAPTR"

    run_query "Registros TLSA" \
        "dig '_443._tcp.$DOMAIN' TLSA"

    run_query "Registros HTTPS" \
        "dig '$DOMAIN' HTTPS"

    run_query "Registros SVCB" \
        "dig '$DOMAIN' SVCB"

    run_query "Registros DNSKEY - chaves DNSSEC" \
        "dig '$DOMAIN' DNSKEY"

    run_query "Registros DS - delegação DNSSEC" \
        "dig '$DOMAIN' DS"

    run_query "Consulta ANY" \
        "dig '$DOMAIN' ANY"

    echo
    echo "================================================================"
    echo "[+] CONSULTAS A SERVIDORES DNS PÚBLICOS"
    echo "================================================================"

    for DNS_SERVER in 1.1.1.1 8.8.8.8 9.9.9.9; do
        run_query "Consulta usando o DNS $DNS_SERVER" \
            "dig '@$DNS_SERVER' '$DOMAIN' ANY"
    done

    echo
    echo "================================================================"
    echo "[+] IDENTIFICANDO SERVIDORES AUTORITATIVOS"
    echo "================================================================"

    NS_SERVERS=$(dig +short NS "$DOMAIN" | sed 's/\.$//' | sort -u)

    if [[ -n "$NS_SERVERS" ]]; then
        echo "[+] Servidores autoritativos encontrados:"
        echo "$NS_SERVERS"
        echo

        for SERVER in $NS_SERVERS; do
            run_query "Consulta direta ao servidor autoritativo $SERVER" \
                "dig '@$SERVER' '$DOMAIN' ANY +stats"

            run_query "Registros NS consultados em $SERVER" \
                "dig '@$SERVER' '$DOMAIN' NS +stats"

            run_query "Registros MX consultados em $SERVER" \
                "dig '@$SERVER' '$DOMAIN' MX +stats"

            run_query "Registros TXT consultados em $SERVER" \
                "dig '@$SERVER' '$DOMAIN' TXT +stats"
        done
    else
        echo "[-] Nenhum servidor autoritativo foi encontrado."
    fi

    echo
    echo "================================================================"
    echo "[+] RESOLVENDO ENDEREÇOS IPv4 E IPv6"
    echo "================================================================"

    IPV4_LIST=$(dig +short "$DOMAIN" A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    IPV6_LIST=$(dig +short "$DOMAIN" AAAA)

    if [[ -n "$IPV4_LIST" ]]; then
        echo "[+] IPv4 encontrados:"
        echo "$IPV4_LIST"
        echo

        for IP in $IPV4_LIST; do
            run_query "Consulta reversa IPv4: $IP" \
                "dig -x '$IP'"
        done
    else
        echo "[-] Nenhum IPv4 encontrado."
    fi

    if [[ -n "$IPV6_LIST" ]]; then
        echo "[+] IPv6 encontrados:"
        echo "$IPV6_LIST"
        echo

        for IP in $IPV6_LIST; do
            run_query "Consulta reversa IPv6: $IP" \
                "dig -x '$IP'"
        done
    else
        echo "[-] Nenhum IPv6 encontrado."
    fi

    run_query "Rastreamento completo da resolução DNS" \
        "dig '$DOMAIN' +trace"

    echo
    echo "================================================================"
    echo "[+] TENTATIVA DE TRANSFERÊNCIA DE ZONA AXFR"
    echo "================================================================"
    echo "[!] Normalmente esta operação é recusada pelos servidores."
    echo

    if [[ -n "$NS_SERVERS" ]]; then
        for SERVER in $NS_SERVERS; do
            run_query "Tentativa AXFR usando o servidor $SERVER" \
                "dig '@$SERVER' '$DOMAIN' AXFR +tcp +stats +multiline"
        done
    else
        echo "[-] Não há servidores autoritativos disponíveis para AXFR."
    fi

    echo
    echo "================================================================"
    echo "FIM DO RELATÓRIO"
    echo "================================================================"
    echo "Domínio analisado: $DOMAIN"
    echo "Arquivo salvo: $OUTPUT"
    echo "Data de término: $(date)"
    echo "================================================================"

} 2>&1 | tee "$OUTPUT"

echo
echo "=============================================="
echo "[+] Execução concluída."
echo "[+] Relatório salvo em:"
echo "    $OUTPUT"
echo "=============================================="
Q
