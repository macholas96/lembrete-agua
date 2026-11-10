#!/bin/bash
echo "Isto remove o LembreteAgua. Espere 60 s para confirmar (Ctrl+C cancela)."
for i in $(seq 60 -1 1); do printf "\r%2ds " "$i"; sleep 1; done; echo
read -r -p 'Digite "quero parar de me hidratar" para confirmar: ' f
[ "$f" = "quero parar de me hidratar" ] || { echo "Cancelado."; exit 1; }
launchctl bootout "gui/$(id -u)/com.lembrete.agua" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.lembrete.agua.plist"
rm -rf "$HOME/Applications/LembreteAgua.app"
echo "Removido. Seu histórico continua em ~/Library/Application Support/LembreteAgua (apague a pasta se quiser)."
