#!/usr/bin/env python3
"""
Script para testar o endpoint de agendamento
Execute: python test_agendamento.py
"""

import requests
import json
from datetime import datetime, timedelta

API_URL = "https://eva-ia.org:8000/api/v1/agendamentos/"

def print_response(test_name, response):
    """Imprime resposta formatada"""
    print(f"📝 {test_name}")
    print(f"📥 Status Code: {response.status_code}")
    print(f"📥 Response Body:")
    try:
        print(json.dumps(response.json(), indent=2, ensure_ascii=False))
    except:
        print(response.text)
    print()

def test_criar_agendamento_valido():
    """Teste 1: Criar agendamento válido"""
    # Data 5 dias no futuro
    data_futura = (datetime.now() + timedelta(days=5)).strftime("%Y-%m-%dT%H:%M:%S")

    payload = {
        "idoso_id": 1,
        "tipo": "chamada_voz",
        "data_hora_agendada": data_futura,
        "prioridade": "normal",
        "status": "agendado"
    }

    print("📤 Request Body:")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    print()

    response = requests.post(API_URL, json=payload)
    print_response("Teste 1: Criar agendamento válido", response)

    if response.status_code in [200, 201]:
        print("✅ Teste 1 PASSOU!")
        return True, response.json()
    else:
        print("❌ Teste 1 FALHOU!")
        return False, None

def test_criar_agendamento_invalido():
    """Teste 2: Criar agendamento com dados inválidos"""
    payload = {
        # "idoso_id": 1,  # REMOVIDO PROPOSITALMENTE
        "tipo": "chamada_voz",
        "data_hora_agendada": "2026-01-30T14:30:00",
        "prioridade": "normal",
        "status": "agendado"
    }

    print("📤 Request Body (sem idoso_id):")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    print()

    response = requests.post(API_URL, json=payload)
    print_response("Teste 2: Criar agendamento inválido (sem idoso_id)", response)

    if response.status_code in [400, 422]:
        print("✅ Teste 2 PASSOU! (Erro esperado)")
        return True
    else:
        print("❌ Teste 2 FALHOU! (Deveria retornar erro 400 ou 422)")
        return False

def test_listar_agendamentos():
    """Teste 3: Listar agendamentos"""
    params = {"idoso_id": 1}

    response = requests.get(API_URL, params=params)
    print_response("Teste 3: Listar agendamentos do idoso 1", response)

    if response.status_code == 200:
        print("✅ Teste 3 PASSOU!")
        return True
    else:
        print("❌ Teste 3 FALHOU!")
        return False

def test_criar_agendamento_video():
    """Teste 4: Criar agendamento de vídeo com alta prioridade"""
    data_futura = (datetime.now() + timedelta(days=3)).strftime("%Y-%m-%dT%H:%M:%S")

    payload = {
        "idoso_id": 1,
        "tipo": "chamada_video",
        "data_hora_agendada": data_futura,
        "prioridade": "alta",
        "status": "agendado"
    }

    print("📤 Request Body:")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    print()

    response = requests.post(API_URL, json=payload)
    print_response("Teste 4: Criar agendamento de vídeo (alta prioridade)", response)

    if response.status_code in [200, 201]:
        print("✅ Teste 4 PASSOU!")
        return True
    else:
        print("❌ Teste 4 FALHOU!")
        return False

def main():
    print("🧪 Testando endpoint de agendamento...")
    print(f"📤 URL: {API_URL}")
    print()
    print("=" * 60)
    print()

    results = []

    try:
        # Teste 1
        passed, agendamento = test_criar_agendamento_valido()
        results.append(("Criar agendamento válido", passed))
        print()
        print("-" * 60)
        print()

        # Teste 2
        passed = test_criar_agendamento_invalido()
        results.append(("Criar agendamento inválido", passed))
        print()
        print("-" * 60)
        print()

        # Teste 3
        passed = test_listar_agendamentos()
        results.append(("Listar agendamentos", passed))
        print()
        print("-" * 60)
        print()

        # Teste 4
        passed = test_criar_agendamento_video()
        results.append(("Criar agendamento vídeo", passed))
        print()

    except requests.exceptions.ConnectionError:
        print("❌ ERRO: Não foi possível conectar ao servidor!")
        print("Verifique se o backend está rodando em: http://104.248.219.200:8000")
        return

    except Exception as e:
        print(f"❌ ERRO INESPERADO: {e}")
        return

    # Resumo
    print()
    print("=" * 60)
    print("🎯 Resumo dos Testes")
    print("=" * 60)

    passed_count = sum(1 for _, passed in results if passed)
    failed_count = len(results) - passed_count

    for test_name, passed in results:
        status = "✅" if passed else "❌"
        print(f"{status} {test_name}")

    print()
    print(f"✅ Testes Passaram: {passed_count}/{len(results)}")
    print(f"❌ Testes Falharam: {failed_count}/{len(results)}")

    if failed_count == 0:
        print()
        print("🎉 Todos os testes passaram! Endpoint funcionando corretamente.")
    else:
        print()
        print("⚠️ Alguns testes falharam. Verifique o backend.")

if __name__ == "__main__":
    main()
