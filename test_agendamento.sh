#!/bin/bash

# Script para testar o endpoint de agendamento
# Execute: bash test_agendamento.sh

API_URL="http://104.248.219.200:8000/api/v1/agendamentos/"

echo "🧪 Testando endpoint de agendamento..."
echo ""
echo "📤 URL: $API_URL"
echo ""

# Teste 1: Criar agendamento válido
echo "📝 Teste 1: Criar agendamento válido"
echo ""

RESPONSE=$(curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "idoso_id": 1,
    "tipo": "chamada_voz",
    "data_hora_agendada": "2026-01-30T14:30:00",
    "prioridade": "normal",
    "status": "agendado"
  }' \
  -s -w "\nHTTP_STATUS:%{http_code}")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "📥 Status Code: $HTTP_STATUS"
echo "📥 Response Body:"
echo "$BODY" | python -m json.tool 2>/dev/null || echo "$BODY"
echo ""

if [ "$HTTP_STATUS" = "201" ] || [ "$HTTP_STATUS" = "200" ]; then
  echo "✅ Teste 1 PASSOU!"
else
  echo "❌ Teste 1 FALHOU!"
fi

echo ""
echo "---"
echo ""

# Teste 2: Criar agendamento com dados inválidos
echo "📝 Teste 2: Criar agendamento com dados inválidos (sem idoso_id)"
echo ""

RESPONSE2=$(curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "tipo": "chamada_voz",
    "data_hora_agendada": "2026-01-30T14:30:00",
    "prioridade": "normal",
    "status": "agendado"
  }' \
  -s -w "\nHTTP_STATUS:%{http_code}")

HTTP_STATUS2=$(echo "$RESPONSE2" | grep "HTTP_STATUS" | cut -d: -f2)
BODY2=$(echo "$RESPONSE2" | sed '/HTTP_STATUS/d')

echo "📥 Status Code: $HTTP_STATUS2"
echo "📥 Response Body:"
echo "$BODY2" | python -m json.tool 2>/dev/null || echo "$BODY2"
echo ""

if [ "$HTTP_STATUS2" = "422" ] || [ "$HTTP_STATUS2" = "400" ]; then
  echo "✅ Teste 2 PASSOU! (Erro esperado)"
else
  echo "❌ Teste 2 FALHOU! (Deveria retornar erro 400 ou 422)"
fi

echo ""
echo "---"
echo ""

# Teste 3: Listar agendamentos
echo "📝 Teste 3: Listar agendamentos do idoso 1"
echo ""

RESPONSE3=$(curl -X GET "$API_URL?idoso_id=1" \
  -H "Content-Type: application/json" \
  -s -w "\nHTTP_STATUS:%{http_code}")

HTTP_STATUS3=$(echo "$RESPONSE3" | grep "HTTP_STATUS" | cut -d: -f2)
BODY3=$(echo "$RESPONSE3" | sed '/HTTP_STATUS/d')

echo "📥 Status Code: $HTTP_STATUS3"
echo "📥 Response Body:"
echo "$BODY3" | python -m json.tool 2>/dev/null || echo "$BODY3"
echo ""

if [ "$HTTP_STATUS3" = "200" ]; then
  echo "✅ Teste 3 PASSOU!"
else
  echo "❌ Teste 3 FALHOU!"
fi

echo ""
echo "========================================="
echo "🎯 Resumo dos Testes"
echo "========================================="

PASSED=0
FAILED=0

if [ "$HTTP_STATUS" = "201" ] || [ "$HTTP_STATUS" = "200" ]; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi

if [ "$HTTP_STATUS2" = "422" ] || [ "$HTTP_STATUS2" = "400" ]; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi

if [ "$HTTP_STATUS3" = "200" ]; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi

echo "✅ Testes Passaram: $PASSED/3"
echo "❌ Testes Falharam: $FAILED/3"

if [ $FAILED -eq 0 ]; then
  echo ""
  echo "🎉 Todos os testes passaram! Endpoint funcionando corretamente."
else
  echo ""
  echo "⚠️ Alguns testes falharam. Verifique o backend."
fi
