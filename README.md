# 老 A 卡跑 ComfyUI（Polaris / gfx803）

**RX 460/470/480/560/570/580/590 这类 2017 年的 A 卡，用 ZLUDA 从零装起 ComfyUI 并出图。**

ROCm 早就砍掉了 Polaris，微软的 DirectML 包也从 GitHub 删了——这张卡按理说只能当废品。
ZLUDA 把它救了回来，代价是版本锁死、坑很多。

---

## 先看结论，再决定装不装

| 模型类别 | 能跑 | 说明 |
|---|---|---|
| **SD 1.5**（2 GB） | ✅ | 512² 20 步约 50 秒 |
| **SDXL**（6.5 GB） | ✅ | 512² 25 步约 64 秒 |
| SD1.5 / SDXL 的 LoRA、ControlNet | ✅ | 同 2D VAE 路线 |
| 复用 **3D VAE** 的模型（Qwen-Image 系等） | ❌ | UNet 能算，但版本里没有 3D VAE 类 |
| 2026 年后的新架构（Anima 等） | ❌ | 模型类在旧版本里不存在 |
| 10B 级大模型（FLUX 等） | ❌ | 单张量与总显存双超 |

**能跑的最新一档就是 SDXL。** 想跑新模型请换卡，别在这上面耗时间。

---

## 怎么用

把仓库交给 Agent，说一句：

> 照着 SKILL.md 在老 A 卡上装 ComfyUI，装完跑一张 SDXL 图给我看

或者自己跑：

```powershell
git clone https://github.com/WYSTAF/polaris-comfyui-zluda
cd polaris-comfyui-zluda
python setup.py          # 自动下 ZLUDA + HIP SDK + 补丁 rocBLAS + torch 2.2 + ComfyUI 0.27
run_zluda.bat            # 启动
```

需要：**Python 3.12**（不能 3.13）、16 GB 内存、12 GB 磁盘、一次管理员权限。

---

## 装之前必须做的三件事

1. **给 `zluda` 目录加杀软排除** —— 它用进程劫持技术，Defender 会当木马删掉，
   删完的报错完全不指向这里
2. **先关浏览器和其他吃内存的程序** —— ZLUDA 在进程内编译内核，内存不足会以
   `LLVM ERROR: out of memory` 死掉
3. **首次启动等 5–10 分钟** —— 在编译 GPU 内核，之后缓存在
   `%LOCALAPPDATA%\ZLUDA\ComputeCache`，别删

---

## 下模型

```powershell
# 看全部可选
powershell -ExecutionPolicy Bypass -File scripts\download_models.ps1 -List

# 下二次元底模（默认 Animagine XL 4.0）
powershell -ExecutionPolicy Bypass -File scripts\download_models.ps1 -Model animagine

# 下最轻的 SD1.5
powershell -ExecutionPolicy Bypass -File scripts\download_models.ps1 -Model sd15
```

内置 9 个热门底模：`illustrious` `noobai` `animagine` `pony` `realvis` `juggernaut`
`sdxl-base`（SDXL 系）与 `sd15` `counterfeit`（SD1.5 系）。全部断点续传。

也可以浏览器直接下，直链格式：

```
https://huggingface.co/<仓库名>/resolve/main/<文件名>
```

放进 `ComfyUI\models\checkpoints\`，在界面按 **R** 刷新。

---

## LoRA

放 `ComfyUI\models\loras\`，SDXL 的 LoRA 只能给 SDXL 用，SD1.5 同理。
加载用 `LoraLoader` 节点（串联可叠多个），强度 0.6–0.8 起试，触发词写进正向提示词最前面。

`assets/workflow_sdxl_lora.json` 已经接好两级 LoRA 槽（默认旁路，不装也能跑）。
细节见 SKILL.md 第五节。

---

## 仓库内容

```
SKILL.md                            完整手册：判定 / 安装 / 下载 / LoRA / 参数 / 实测 / 排错
README.md                           本文件
scripts/download_models.ps1         9 个热门底模，断点续传
assets/workflow_sdxl_anime.json     SDXL 文生图，参数按本卡白名单调好
assets/workflow_sdxl_lora.json      SDXL + 双 LoRA 槽（默认旁路）
```

---

## 两条硬限制（记这两条就够）

- **单次分配 ≤ 2 GB**（2.0 GB 可以，2.5 GB 段错误）
- **总可用显存 ~6 GB**（卡报 8 GB，实际能用的少 1–2 GB）

SDXL 能跑是因为它最大单张量只有 56 MB，不触第一条。

---

## 许可

本仓库文档与脚本可自由取用。ZLUDA、HIP SDK、rocBLAS 从其各自作者处下载并遵守各自许可；
ComfyUI 遵循自身许可证；各底模遵循其 HuggingFace 页面标注的许可。
