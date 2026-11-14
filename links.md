# 章ごとの参考リンク集

各章の最後の節「参考 URL」に載せたリンクです。脚注の出典は本書をご覧ください。

## 第1章 DB屋のためのMCP入門

- MCP 仕様 2026-07-28 版（Architecture・Key Changes・Server Features・Tools・Schema Reference・Transports・Authorization の各ページ）: <https://modelcontextprotocol.io/specification/2026-07-28>
- Claude Code Docs（MCP の設定・Desktop application の各ページ）: <https://code.claude.com/docs/en/mcp>

## 第2章 AWSのMCPサーバをAuroraに繋ぐ

- awslabs/mcp postgres-mcp-server README（GitHub）: <https://github.com/awslabs/mcp/tree/main/src/postgres-mcp-server>
- awslabs/mcp postgres-mcp-server CHANGELOG（GitHub）: <https://github.com/awslabs/mcp/blob/main/src/postgres-mcp-server/CHANGELOG.md>
- awslabs/mcp Issue #4115 aws-api-mcp-server の開発終了（GitHub・2026-07-10）: <https://github.com/awslabs/mcp/issues/4115>
- Amazon RDS Data API の使用（AWS Docs）: <https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/AuroraUserGuide/data-api.html>
- AWS MCP Server ユーザーガイド（Setting up・IAM・OAuth 2.1 authentication・CloudTrail の各ページ）: <https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html>
- AWS 公式の Postgres MCP Server を Claude Desktop から Aurora につないでみた — Data API と直接接続を同一クラスタで比較（Qiita・2026-07-02・2.3節の出典）: <https://qiita.com/asahide/items/a5df6cb7173c2fc534a2>
- AWS MCP Server 経由のエージェントを IAM で絞る（Qiita・2026-10-09・ポリシーの全文と境界の確認表はこちら）: <https://qiita.com/asahide/items/050edb6e7a9496c6b207>

## 第3章 「いま重いSQLを3件教えて」をAuroraで

- pg_stat_statements（PostgreSQL Documentation）: <https://www.postgresql.org/docs/current/pgstatstatements.html>
- 「いま重い SQL を 3 件教えて」を Claude から Aurora に聞いてみた：MCP でつなぐ pg_stat_statements と Database Insights（Qiita・2026-07-09・会話の画面つき）: <https://qiita.com/asahide/items/ada9f74d419a9358b1a8>

## 第4章 本番に向けて決めること

- Aurora の診断ランブックを Claude の Skill にすると「いま重い SQL」の答えはどう変わるか（Qiita・2026-07-17）: <https://qiita.com/asahide/items/bbfc1b81b89e745b182b>
