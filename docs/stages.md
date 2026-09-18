# 阶段提交索引

所有下列提交均从已有交付快照事后补建，使用实际导入时间；不是伪造的原始开发历史。个人路径及真实数据细节已从公开快照中清理，原始交付包哈希用于说明来源，原 ZIP 不进入仓库。

| 阶段 | 提交 | 内容 / 入口 |
|---|---|---|
| P0-v1 | [cd01513f](https://github.com/LeoMY1/desktop-timer/tree/cd01513f7ea9f74e43e0b04797e3a7827d9b58df) | 设计稿，无应用代码 |
| P0-v2 | [621f44ec](https://github.com/LeoMY1/desktop-timer/tree/621f44ec4ea7d9e67a4189ec410a464d9b8e38d4) | 设计稿，无应用代码 |
| P0-v3 | [12783e9a](https://github.com/LeoMY1/desktop-timer/tree/12783e9ad8e2ab987504d8f2729df88c2ae84a62) | 设计稿，无应用代码 |
| P1 | [7154d3a9](https://github.com/LeoMY1/desktop-timer/tree/7154d3a9ea72271e2884ff45731d10f81b8ecaba) | 需求与规格，无应用代码 |
| P2-v1 | [24d1669f](https://github.com/LeoMY1/desktop-timer/tree/24d1669f2a029c409ea20285eb504b96064bbbe9) | bash scripts/build.sh release |
| P2-v2 | [e09b68dc](https://github.com/LeoMY1/desktop-timer/tree/e09b68dcaa909299a7498bf07eef6c7661268538) | bash scripts/build.sh release |
| P2-v3 | [5adf8518](https://github.com/LeoMY1/desktop-timer/tree/5adf8518a9ca357fefbaf941b58a95338bb18acf) | bash scripts/build.sh release |
| P3-v1 | [f649dcf9](https://github.com/LeoMY1/desktop-timer/tree/f649dcf99eb9ce3492bd6ff6531486473ee0a535) | bash scripts/build-p3.sh release |
| P4-v1 | [6ceabf55](https://github.com/LeoMY1/desktop-timer/tree/6ceabf55dc4c23c16221869dff46a02bea95303d) | bash scripts/build-p4.sh release |
| P4-v2 | [b36f5ff9](https://github.com/LeoMY1/desktop-timer/tree/b36f5ff9ba07367481b456f9010c416bb52cc225) | bash scripts/build-p4.sh release |
| P5-v1 | [3092ce0c](https://github.com/LeoMY1/desktop-timer/tree/3092ce0ca98532528ec402155262eda100728c9e) | bash scripts/build-p5.sh release |

使用 `git show <提交>:README.md` 查看当时说明。需要构建旧版时，可在独立目录执行 `git worktree add --detach <目录> <提交>`，按该阶段入口构建；测试也应隔离数据库。

历史报告是原交付证据，并非本轮重测。开源整理只核对旧快照完整性和入口；当前版本重新回归见 [验证记录](validation.md)。
