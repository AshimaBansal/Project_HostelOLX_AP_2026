# CP4 — Query Execution Timings

Database: `hostelolx_ap`
Generated: 2026-11-23T20:40:28

Each query was attempted three times using `EXPLAIN (ANALYZE, BUFFERS)`.
Each execution was performed inside a single transaction and rolled back.
Write operations were not committed.
Failed executions are marked honestly and their output is preserved in the plan files.

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Status |
|---|---|---:|---:|---:|---:|---|
| R1 | READ | 0.019 | 0.031 | 0.017 | 0.022 | 3/3 successful |
| R2 | READ | 0.071 | 0.044 | 0.055 | 0.057 | 3/3 successful |
| R3 | READ | 0.060 | 0.046 | 0.049 | 0.052 | 3/3 successful |
| R4 | READ | 0.039 | 0.040 | 0.038 | 0.039 | 3/3 successful |
| R5 | READ | 0.009 | 0.009 | 0.008 | 0.009 | 3/3 successful |
| W1 | WRITE | 0.052 | 0.045 | 0.046 | 0.048 | 3/3 successful |
| R6 | READ | 0.056 | 0.055 | 0.050 | 0.054 | 3/3 successful |
| R7 | READ | 0.019 | 0.018 | 0.021 | 0.019 | 3/3 successful |
| R8 | READ | 0.032 | 0.030 | 0.037 | 0.033 | 3/3 successful |
| R9 | READ | 0.026 | 0.026 | 0.026 | 0.026 | 3/3 successful |
| R10 | READ | 0.044 | 0.031 | 0.028 | 0.034 | 3/3 successful |
| R11 | READ | 0.035 | 0.029 | 0.034 | 0.033 | 3/3 successful |
| R12 | READ | 0.039 | 0.044 | 0.037 | 0.040 | 3/3 successful |
| R13 | READ | 0.029 | 0.038 | 0.032 | 0.033 | 3/3 successful |
| R14 | READ | 0.023 | 0.020 | 0.019 | 0.021 | 3/3 successful |
| R15 | READ | 0.041 | 0.042 | 0.042 | 0.042 | 3/3 successful |
| R16 | READ | 0.038 | 0.030 | 0.029 | 0.032 | 3/3 successful |
| R17 | READ | 0.044 | 0.045 | 0.045 | 0.045 | 3/3 successful |
| R18 | READ | 0.017 | 0.015 | 0.017 | 0.016 | 3/3 successful |
| W2 | WRITE | — | — | — | — | 0/3 successful |
| W3 | WRITE | — | — | — | — | 0/3 successful |
| W4 | WRITE | 0.059 | 0.041 | 0.042 | 0.047 | 3/3 successful |
| W5 | WRITE | 0.042 | 0.040 | 0.041 | 0.041 | 3/3 successful |
| W6 | WRITE | 0.041 | 0.041 | 0.041 | 0.041 | 3/3 successful |
| W7 | WRITE | 0.048 | 0.045 | 0.044 | 0.046 | 3/3 successful |
| R19 | READ | 0.035 | 0.029 | 0.041 | 0.035 | 3/3 successful |
| R20 | READ | 0.028 | 0.021 | 0.023 | 0.024 | 3/3 successful |
| W8 | WRITE | — | — | — | — | 0/3 successful |
| W9 | WRITE | 0.050 | 0.049 | 0.047 | 0.049 | 3/3 successful |
| R21 | READ | 0.042 | 0.035 | 0.033 | 0.037 | 3/3 successful |
| R22 | READ | 0.036 | 0.035 | 0.035 | 0.035 | 3/3 successful |
| W10 | WRITE | — | — | — | — | 0/3 successful |
| W11 | WRITE | 0.056 | 0.047 | 0.053 | 0.052 | 3/3 successful |
| W12 | WRITE | 0.042 | 0.040 | 0.042 | 0.041 | 3/3 successful |
| R23 | READ | 0.038 | 0.034 | 0.034 | 0.035 | 3/3 successful |
| R24 | READ | 0.036 | 0.035 | 0.037 | 0.036 | 3/3 successful |
| W13 | WRITE | 0.026 | 0.029 | 0.028 | 0.028 | 3/3 successful |
| W14 | WRITE | 0.054 | 0.041 | 0.042 | 0.046 | 3/3 successful |
| W15 | WRITE | 0.050 | 0.053 | 0.043 | 0.049 | 3/3 successful |
| W16 | WRITE | — | — | — | — | 0/3 successful |
| W17 | WRITE | 0.071 | 0.065 | 0.066 | 0.067 | 3/3 successful |
| R25 | READ | 0.044 | 0.045 | 0.045 | 0.045 | 3/3 successful |
| R26 | READ | 0.021 | 0.020 | 0.020 | 0.020 | 3/3 successful |
| R27 | READ | 0.032 | 0.030 | 0.032 | 0.031 | 3/3 successful |
| R28 | READ | 0.034 | 0.034 | 0.034 | 0.034 | 3/3 successful |
| R29 | READ | 0.019 | 0.021 | 0.019 | 0.020 | 3/3 successful |
| W18 | WRITE | 0.023 | 0.024 | 0.023 | 0.023 | 3/3 successful |
| W19 | WRITE | — | — | — | — | 0/3 successful |
| W20 | WRITE | 0.047 | 0.047 | 0.049 | 0.048 | 3/3 successful |
| W21 | WRITE | 0.051 | 0.048 | 0.051 | 0.050 | 3/3 successful |
| R30 | READ | 0.051 | 0.051 | 0.065 | 0.056 | 3/3 successful |
| R31 | READ | 0.028 | 0.026 | 0.030 | 0.028 | 3/3 successful |
| R32 | READ | 0.030 | 0.027 | 0.029 | 0.029 | 3/3 successful |
| R33 | READ | 0.034 | 0.026 | 0.027 | 0.029 | 3/3 successful |
| R34 | READ | 0.018 | 0.017 | 0.017 | 0.017 | 3/3 successful |
| W22 | WRITE | — | — | — | — | 0/3 successful |
| W23 | WRITE | 0.050 | 0.039 | 0.038 | 0.042 | 3/3 successful |
| W24 | WRITE | — | — | — | — | 0/3 successful |
| W25 | WRITE | 0.044 | 0.043 | 0.043 | 0.043 | 3/3 successful |
| W26 | WRITE | 0.042 | 0.039 | 0.044 | 0.042 | 3/3 successful |
| W27 | WRITE | 0.044 | 0.040 | 0.052 | 0.045 | 3/3 successful |
| R35 | READ | 0.038 | 0.036 | 0.038 | 0.037 | 3/3 successful |
| W28 | WRITE | 0.017 | 0.017 | 0.016 | 0.017 | 3/3 successful |

## Notes

- Detailed execution plans are available in `dbms/plans/`.
- Each query execution is isolated in a transaction.
- All benchmark transactions are rolled back.
- Queries requiring fixture data may return zero rows.
- Failed queries are documented in their respective plan files.
