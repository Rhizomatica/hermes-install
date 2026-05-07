#!/bin/bash

# ========== FUNÇÕES ==========
erro() {
    zenity --error --text="$1"
    exit 1
}

info() {
    zenity --info --text="$1"
}

# ========== ARQUIVO DE ESTAÇÕES ==========
STATIONS_FILE="stations"

# ========== COLETA MÚLTIPLAS ESTAÇÕES ==========
declare -a estacoes_nomes=()
declare -a estacoes_tipos=()

while true; do
    # Pede o nome da estação
    sleep 0.1
    nome_estacao=$(zenity --entry \
        --title="New Station" \
        --text="Enter the name of the station (or leave empty to finish):" \
        --entry-text="")
    
    # Se vazio, sai do loop
    if [ -z "$nome_estacao" ]; then
        if [ ${#estacoes_nomes[@]} -eq 0 ]; then
            erro "No station has been added!"
        fi
        break
    fi
    
    # Pede o tipo da estação
    sleep 0.1
    tipo_estacao=$(zenity --list --radiolist \
        --title="Type of Station - $nome_estacao" \
        --text="Select the type of station '$nome_estacao':" \
        --column="Select" \
        --column="Type" \
        --column="Description" \
        FALSE "remote" "Remote Station" \
        FALSE "gateway" "Gateway Station")
    
    if [ -z "$tipo_estacao" ]; then
        zenity --warning --text="Type not selected for '$nome_estacao'! Station ignored."
        continue
    fi
    
    # Adiciona aos arrays
    estacoes_nomes+=("$nome_estacao")
    estacoes_tipos+=("$tipo_estacao")
    
    # Mostra confirmação
    info "✅ Station added:\n\nName: $nome_estacao\nType: $tipo_estacao"
    
    # Pergunta se quer adicionar mais
    sleep 0.1
    zenity --question \
        --title="Add more?" \
        --text="Station '$nome_estacao' added!\n\nDo you want to add another station?" \
        --ok-label="Yes, add more" \
        --cancel-label="No, continue"
    
    if [ $? -ne 0 ]; then
        break
    fi
done

# Mostra resumo das estações
resumo="Stations added:\n\n"
for i in "${!estacoes_nomes[@]}"; do
    resumo="${resumo}$((i+1)) - ${estacoes_nomes[$i]} (${estacoes_tipos[$i]})\n"
done

info "$resumo"

# ========== SALVA NO ARQUIVO STATIONS ==========
# Cria backup do arquivo antigo se existir
if [ -f "$STATIONS_FILE" ]; then
    cp "$STATIONS_FILE" "${STATIONS_FILE}.bak"
    zenity --info --text="Backup created: ${STATIONS_FILE}.bak"
fi

# Limpa o arquivo e salva no formato: nome|tipo
> "$STATIONS_FILE"
for i in "${!estacoes_nomes[@]}"; do
    echo "${estacoes_nomes[$i]}|${estacoes_tipos[$i]}" >> "$STATIONS_FILE"
done

info "✅ ${#estacoes_nomes[@]} station(s) saved to $STATIONS_FILE"

stations=()
stations_types=()
while IFS='|' read -r nome tipo; do
    nome=$(echo "$nome" | tr -d ' ')
    tipo=$(echo "$tipo" | tr -d ' ')
    if [ -n "$nome" ] && [[ ! "$nome" =~ ^# ]]; then
        stations+=("$nome")
        stations_types+=("$tipo")
    fi
done < "$STATIONS_FILE"

if [ ${#stations[@]} -eq 0 ]; then
    erro "No valid stations in file!"
fi

# Mostra as estações carregadas com seus tipos
debug_msg="Stations loaded from file:\n"
for i in "${!stations[@]}"; do
    debug_msg="${debug_msg}${stations[$i]} = ${stations_types[$i]}\n"
done
echo "$debug_msg"

# ========== CALLSIGN ==========
sleep 0.1
callsign=$(zenity --entry --title="Callsign" --text="Enter the Callsign:")

if [ -z "$callsign" ]; then
    erro "Callsign not provided!"
fi

# ========== VARA KEY ==========
sleep 0.1
vara_key=$(zenity --entry --title="VARA Key" --text="Enter the VARA Key for $callsign:")

if [ -z "$vara_key" ]; then
    erro "VARA Key not provided!"
fi

info "Callsign: $callsign\nVARA Key: $vara_key"

# ========== NETWORK NAME ==========
sleep 0.1
uucp_net=$(zenity --entry --title="Network" --text="Network name:" --entry-text="hermes")

if [ -z "$uucp_net" ]; then
    exit 0
fi

sys_file="sys.$uucp_net"
sys_file_gw="sys-gw.$uucp_net"
transport_file="transport.$uucp_net"

#
TEMPLATE_FILE=""

#  
possible_paths=(
    "base.template"
    "../base.template"
    "../../base.template"
    "../../../base.template"
    "./templates/base.template"
    "../templates/base.template"
    "../../templates/base.template"
    "../../../templates/base.template"
)

for path in "${possible_paths[@]}"; do
    if [ -f "$path" ]; then
        TEMPLATE_FILE="$path"
        break
    fi
done

# 
if [ -z "$TEMPLATE_FILE" ]; then
    TEMPLATE_FILE=$(find . -name "base.template" -type f 2>/dev/null | head -1)
fi

#  
if [ -z "$TEMPLATE_FILE" ] || [ ! -f "$TEMPLATE_FILE" ]; then
    erro "Template file 'base.template' not found!\n\nSearched in:\n$(printf '%s\n' "${possible_paths[@]}")\n\nPlease make sure base.template exists in the script directory."
fi

template=$(cat "$TEMPLATE_FILE")
zenity --info --text="✅ Template found and loaded:\n\n📄 $TEMPLATE_FILE"

# ========== LANGUAGE ==========
sleep 0.1
language=$(zenity --list --radiolist \
    --title="Language" \
    --text="Select the language:" \
    --column="Select" \
    --column="Language" \
    --column="Code" \
    FALSE "Arabic" "ar" \
    FALSE "French" "fr" \
    FALSE "Portuguese" "pt" \
    FALSE "Spanish" "es" \
    FALSE "English" "en")

if [ -z "$language" ]; then
    exit 0
fi

# ========== TIMEZONE ==========
sleep 0.1
timezone=$(zenity --list --radiolist \
    --title="Timezone" \
    --text="Select the timezone:" \
    --column="Select" \
    --column="Timezone" \
    FALSE "UTC" \
    FALSE "America/Guayaquil" \
    FALSE "Africa/Central" \
    FALSE "Africa/Cairo" \
    FALSE "America/Sao_Paulo" \
    FALSE "America/New_York" \
    FALSE "America/Manaus")

if [ -z "$timezone" ]; then
    exit 0
fi

info "Creating files: $sys_file, $sys_file_gw, $transport_file"

# ========== CRIA SYS, SYS-GW E TRANSPORT ==========
> "$sys_file"
> "$sys_file_gw"
> "$transport_file"

# SYS file
cat >> "$sys_file" << SYS_EOF
time any

chat-timeout 600
call-login user
call-password pass
chat "" \r

port HFP

forward ANY
commands rmail crmail bash uucp sudo dec_sensors dec_message

protocol y
protocol-parameter y packet-size 512
protocol-parameter y timeout 5400

system $callsign
alias gw

SYS_EOF

# SYS-GW file
cat >> "$sys_file_gw" << SYSGW_EOF
time any

chat-timeout 600
call-login user
call-password pass
chat "" \r

port HFP

forward *
commands rmail crmail bash uucp sudo dec_sensors dec_message

protocol yiG
protocol-parameter y packet-size 512
protocol-parameter y timeout 5400

system hermes
alias gw
port TCP
protocol G
address 10.70.96.1
chat "" \d\d\r\c ogin: \d\L word: \P

system $callsign
alias local

SYSGW_EOF

#  
for i in "${!stations[@]}"; do
    estacao="${stations[i]}"
    num=$((i+1))
    
    cat >> "$sys_file" << SYS_EOF
system ${callsign}-${num}
alias ${estacao}

SYS_EOF

    cat >> "$sys_file_gw" << SYSGW_EOF
system ${callsign}-${num}
alias ${estacao}

SYSGW_EOF

    echo "${estacao}.hermes.radio    uucp:${estacao}" >> "$transport_file"
done

# ========== created file stations ==========
(
contador=0
total=${#stations[@]}

for i in "${!stations[@]}"; do
    ((contador++))
    
    estacao="${stations[$i]}"
    tipo_estacao="${stations_types[$i]}"
    arquivo_estacao="${estacao}.hermes.radio"
    
    echo "# Creating: $arquivo_estacao (type: $tipo_estacao)"
    
    # Substitui variáveis no template
    conteudo="$template"
    conteudo="${conteudo//\{\{NOME_BASE\}\}/$estacao}"
    conteudo="${conteudo//\{\{HERMES_LANGUAGE\}\}/$language}"
    conteudo="${conteudo//\{\{TIMEZONE\}\}/$timezone}"
    conteudo="${conteudo//\{\{UUCP_NET\}\}/$uucp_net}"
    conteudo="${conteudo//\{\{NUMERO_SEQUENCIA\}\}/$contador}"
    conteudo="${conteudo//\{\{VARA\}\}/$callsign}"
    conteudo="${conteudo//\{\{HERMES_ROLE\}\}/$tipo_estacao}"
    conteudo=$(echo "$conteudo" | sed "s/VARA_KEY=\"[^\"]*\"/VARA_KEY=\"$vara_key\"/")
    
    echo "$conteudo" > "$arquivo_estacao"
    
    echo "$((contador * 100 / total))"
    echo "# Created: $arquivo_estacao ($tipo_estacao)"
    sleep 0.1
done

echo "100"
echo "# Completed!"
) | zenity --progress --title="Creating files" --text="Generating configurations..." --auto-close --percentage=0

# ==========  FINAL ==========
resumo_final="✅ Configuration completed!\n\n"
resumo_final="${resumo_final}📡 Callsign: $callsign\n"
resumo_final="${resumo_final}🔑 VARA Key: $vara_key\n"
resumo_final="${resumo_final}🌐 Network: $uucp_net\n"
resumo_final="${resumo_final}🗣 Language: $language\n"
resumo_final="${resumo_final}🕒 Timezone: $timezone\n\n"
resumo_final="${resumo_final}📊 Stations configured (${#stations[@]}):\n"

for i in "${!stations[@]}"; do
    resumo_final="${resumo_final}$((i+1)) - ${stations[$i]} (${stations_types[$i]})\n"
done

info "$resumo_final"

# ========== MOVE files ==========
DEST_STATIONS="../../../stations/"
DEST_CONF="../../"

[ ! -d "$DEST_STATIONS" ] && mkdir -p "$DEST_STATIONS"

#  
mv *.hermes.radio "$DEST_STATIONS" 2>/dev/null
mv "$sys_file" "$sys_file_gw" "$transport_file" "$DEST_CONF" 2>/dev/null

info "Files moved successfully!\n\n📁 Stations: $DEST_STATIONS\n📁 Config: $DEST_CONF"

# ========== EXECUTA INSTALLER.SH PARA CADA ESTAÇÃO ==========
INSTALLER_SCRIPT="../../../installer.sh"

# Verifica se o installer.sh existe
if [ ! -f "$INSTALLER_SCRIPT" ]; then
    zenity --warning --text="Installer script not found at: $INSTALLER_SCRIPT\n\nSkipping installation step."
else
    # Pergunta se quer executar o installer
    zenity --question \
        --title="Run Installer" \
        --text="Do you want to run installer.sh for each station?\n\n${#stations[@]} station(s) will be installed." \
        --ok-label="Yes, run installer" \
        --cancel-label="No, skip"
    
    if [ $? -eq 0 ]; then
        # Array para armazenar resultados
        declare -a resultados=()
        
        # Executa installer para cada estação
        (
            echo "0"
            echo "# Preparing to run installer..."
            
            total_estacoes=${#stations[@]}
            for i in "${!stations[@]}"; do
                estacao="${stations[$i]}"
                arquivo_estacao="${estacao}.hermes.radio"
                caminho_completo="${DEST_STATIONS}${arquivo_estacao}"
                
                echo "$(( (i * 100) / total_estacoes ))"
                echo "# Running installer for: $estacao"
                
                # Executa o installer.sh com o arquivo como parâmetro
                cd ../..  # Vai para a pasta correta (onde está installer.sh)
                output=$("$INSTALLER_SCRIPT" "$caminho_completo" 2>&1)
                codigo_saida=$?
                cd - > /dev/null  # Volta para a pasta original
                
                if [ $codigo_saida -eq 0 ]; then
                    resultados+=("✅ $estacao - OK")
                    echo "# ✅ $estacao installed successfully"
                else
                    resultados+=("❌ $estacao - FAILED (exit code: $codigo_saida)")
                    echo "# ❌ $estacao installation failed"
                fi
                
                sleep 0.5
            done
            
            echo "100"
            echo "# Installation completed!"
        ) | zenity --progress --title="Running Installer" --text="Installing stations..." --auto-close --percentage=0 --width=500
        
        # Mostra o resumo da instalação
        resumo_install="Installation Results:\n\n"
        for resultado in "${resultados[@]}"; do
            resumo_install="${resumo_install}${resultado}\n"
        done
        
        info "$resumo_install"
    else
        info "Installation skipped. You can run manually later:\n\nfor file in $DEST_STATIONS*.hermes.radio; do\n  ../../../installer.sh \"\$file\"\ndone"
    fi
fi

echo "✅ Script completed successfully!"