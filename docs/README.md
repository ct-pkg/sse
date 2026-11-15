# ct-sse 文档索引

> 本页是 `docs/` 的入口；每个 Markdown 都必须能从这里直达。
> 链接检查：`python3 tools/check_links.py`（缺失数为 0 才算通过）。

## 1 五层产物

| 层 | 文档 | 回答什么 |
| --- | --- | --- |
| 提案（原文留档） | [proposal.md](proposal.md) | 最初想做什么；正文不改，推翻项在评估里纠正 |
| 研判评估 | [evaluation.md](reviews/evaluation.md) | 十六个问题各自的结论与实测依据 |
| 需求定稿 | [requirements.md](requirements.md) | 要什么、不要什么、边界在哪 |
| 路线图 | [planning/roadmap.md](planning/roadmap.md) | 片序、依赖、二值判据、版本落点 |
| phase 卡 | [phases/PH-01/card.md](phases/PH-01/card.md) … [PH-14](phases/PH-14/card.md) | 每片的判据、交付物、回滚、版本位 |

## 2 契约与阶段卡

- 契约冻结：[phases/S0/card.md](phases/S0/card.md)
- 已完成片回溯卡：[PH-01](phases/PH-01/card.md)、[PH-02](phases/PH-02/card.md)、
  [PH-03](phases/PH-03/card.md)、[PH-04](phases/PH-04/card.md)、
  [PH-05](phases/PH-05/card.md)、[PH-06](phases/PH-06/card.md)、
  [PH-07](phases/PH-07/card.md)、[PH-08](phases/PH-08/card.md)、
  [PH-09](phases/PH-09/card.md)、[PH-10](phases/PH-10/card.md)
- 待开工/阻塞片：[PH-11](phases/PH-11/card.md)、[PH-12](phases/PH-12/card.md)、
  [PH-13](phases/PH-13/card.md)、[PH-14](phases/PH-14/card.md)

## 3 评审与实测记录

- 语言事实与设计裁定：[S0-facts.md](reviews/S0-facts.md)、[S0-battle.md](reviews/S0-battle.md)
- 构造形态探针：[S0-constructor-shapes.md](reviews/S0-constructor-shapes.md)
- 契约收口核对：[S0-closeout.md](reviews/S0-closeout.md)
- 内置类型宿主能力表：[S8-int-host.md](reviews/S8-int-host.md)
- 分配器、OOM、计数、四类记账、finish 可观测性：[S9-allocator.md](reviews/S9-allocator.md)
- ct-http 真实对接：[S13-http-integration.md](reviews/S13-http-integration.md)
- 契约细则覆盖表（两席 battle）：[S14-coverage.md](reviews/S14-coverage.md)
- 依赖方向与 ct-http 审计：[S16-dependency-direction.md](reviews/S16-dependency-direction.md)

## 4 分析、设计与历史

- 提案期分析：[analysis.md](analysis.md)
- 提案期设计：[design.md](design.md)
- 会话到产物的映射：[session-map.md](session-map.md)
- 工程规范：[spec/ai-coding-workflow.md](spec/ai-coding-workflow.md)

## 5 本仓待办与已决事项

- [planning/backlog.md](planning/backlog.md)：包清单的发布者/命名根、发布 tag、构造形态决定，
  以及各自的等待条件与验收方式。

## 6 门禁入口

- 单包夹具：`bash test/run.sh <task>`（构建零警告 + 逐字节 diff）
- 全量清单与 ASan 子集：[roadmap §6](planning/roadmap.md)
- 独立集成门禁：`bash test/integration.sh`
- 文档检查：`python3 tools/check_links.py`、`python3 tools/check_api.py`
