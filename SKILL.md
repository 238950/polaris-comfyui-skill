---
name: polaris-comfyui
description: 在 AMD Polaris/Vega 老卡（RX 460/470/480/560/570/580/590、Vega 56/64，gfx803/gfx900）上用 ZLUDA 从零装起 ComfyUI 并出图。涵盖能力边界判定（哪些模型能跑、哪些是死路及技术原因）、ZLUDA 三板斧安装、热门 SDXL/SD1.5 底模下载、LoRA 的下载与加载节点、ZLUDA 环境下的采样器白名单，以及杀软误报/内存不足/3D-VAE 等典型故障。当用户要在这类老 A 卡上跑本地生图，或问某模型能不能在这张卡上跑时使用。
agent_created: true
---

# 老 A 卡跑 ComfyUI（ZLUDA / gfx803）

> 本文假设**全新机器、零环境**，从装 Python 开始。不依赖任何既有目录或配置。
> 第一件事是判定能不能跑——装完了发现模型跑不起来，比不装更浪费时间。

## 一、适用硬件

| 架构 | 显卡 | 状态 |
|---|---|---|
| **gfx803**（Polaris） | RX 460 / 470 / 480 / 560 / 570 / 580 / 590 | ✅ 实测可用 |
| **gfx900**（Vega） | RX Vega 56 / 64 | ⚠️ 内核在，未实测 |
| 更新的卡 | RX 5000 / 6000 / 7000（Navi / RDNA） | ❌ 补丁版 rocBLAS 里没有对应内核 |

原因：AMD 在 ROCm v5.x 里永久移除了 Polaris；微软的 `torch-directml` 已于 2024-09
删除仓库。剩下的唯一通道是 **ZLUDA**，且必须用 `lshqqytiger` 分支 + 打过 gfx803
内核补丁的 rocBLAS——上游 `vosen/ZLUDA` 明确不支持这些卡。

```
ComfyUI → ZLUDA（翻译 CUDA 调用） → HIP SDK → 打补丁的 rocBLAS → 显卡
```

---

## 二、能力边界（装之前必读）

**两条硬限制**，任何参数都绕不过：

1. **单次分配 ≤ ~2 GB**（实测 2.0 GB 可以，2.5 GB 直接段错误）
2. **总可用显存 ~6 GB**（卡报 8 GB，实际能用的多张小张量加起来 5–6 GB）

真正的天花板是**版本锁**：ComfyUI 只能到 **v0.27.0**。因为 v0.37+ 的 `comfy-kitchen`
强制 torch ≥ 2.7，而 gfx803 在 ZLUDA 下跑不了 CUDA 12+ / torch ≥ 2.4。
torch 只能停在 **2.2.x**。

| 模型类别 | 能跑吗 | 原因 |
|---|---|---|
| **SD 1.5**（fp16 2 GB） | ✅ | 2D VAE，512² 20 步 45–50 秒 |
| **SDXL**（6.5 GB） | ✅ | 2D VAE，最大单张量仅 56 MB，不触 2 GB 限制 |
| SD1.5 / SDXL 的 ControlNet、inpaint、LoRA | ✅ 预期 | 同 2D VAE 路线 |
| **复用 3D VAE 的模型**（Qwen-Image 系列等） | ❌ | UNet 能加载能算，但 v0.27.0 没有匹配的 3D VAE 类——它的 VAE 是 3D 卷积 + RMS norm 的混合体，和 `AutoencoderKL`、`vae_refiner` 都对不上 |
| **需要 ComfyUI ≥0.35 的新架构**（Anima 等 2026 年新发布的 DiT） | ❌ | 模型类在旧版本里根本不存在 |
| **10B 级大模型**（FLUX 等） | ❌ | 单张量与总显存双超 |

> 结论：**能跑的最新一档就是 SDXL。** 想要好效果就在 SDXL 底模和 LoRA 上做文章，
> 别指望在这张卡上跑 2026 年之后发布的新架构。

---

## 三、安装（三步）

### 前置

| 项 | 要求 |
|---|---|
| 系统 | Windows 10 22H2 (19045) 或 Windows 11 |
| Python | **必须 3.12**——预编译轮子没有 3.13 版本 |
| 内存 | **16 GB 推荐**，8 GB 会很吃力 |
| 磁盘 | 装环境 12 GB + 模型空间 |
| 权限 | 装 HIP SDK 需要一次管理员 |
| 网络 | 约 4 GB 下载（torch 轮子 2.6 GB） |

### 步骤

```powershell
# 1) 拉安装器
git clone https://github.com/WYSTAF/polaris-comfyui-zluda
cd polaris-comfyui-zluda

# 2) 一键装（自动下 ZLUDA + HIP SDK + 补丁 rocBLAS + torch 2.2 + ComfyUI v0.27.0）
python setup.py

# 3) 启动
run_zluda.bat
```

装完打开 <http://127.0.0.1:8188>。默认装在 `ComfyUI` 子目录，模型目录是
`ComfyUI\models\`。

**先做这三件事**，否则会白耗一晚上：

1. **给 `zluda` 目录加杀软排除**——它用进程劫持技术，Defender 会当木马删掉，
   删完的报错完全不指向这里。
2. **先关浏览器和其他吃内存的程序**——ZLUDA 在 Python 进程内编译 GPU 内核，
   要额外几 GB，内存不够会以 `LLVM ERROR: out of memory` 死掉。
3. **首次启动等 5–10 分钟**——在编译内核，之后缓存在
   `%LOCALAPPDATA%\ZLUDA\ComputeCache`，**别删**。

---

## 四、热门底模下载

### SDXL（推荐，6.5 GB 左右）

| 模型 | 风格 | 直链 |
|---|---|---|
| Illustrious-XL v1.0 | 二次元（tag 系） | `huggingface.co/OnomaAIResearch/Illustrious-XL-v1.0` → `Illustrious-XL-v1.0.safetensors` |
| NoobAI-XL v1.1 | 二次元（Illustrious 衍生，更宽的画师覆盖） | `Laxhar/noobai-XL-1.1` → `NoobAI-XL-v1.1.safetensors` |
| Animagine XL 4.0 | 二次元（开箱即用，参数友好） | `cagliostrolab/animagine-xl-4.0` → `animagine-xl-4.0.safetensors` |
| Pony Diffusion V6 XL | 二次元（自成一套 tag 体系） | `astraliteheart/pony-diffusion-v6` → `v6.safetensors` |
| RealVisXL V4.0 | 写实 | `SG161222/RealVisXL_V4.0` → `RealVisXL_V4.0.safetensors` |
| Juggernaut XL v9 | 写实/摄影 | `RunDiffusion/Juggernaut-XL-v9` → `Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors` |
| SDXL base 1.0 | 官方基线（拿来做 LoRA 训练） | `stabilityai/stable-diffusion-xl-base-1.0` → `sd_xl_base_1.0.safetensors` |

### SD1.5（2 GB，跑得最快）

| 模型 | 风格 | 直链 |
|---|---|---|
| SD 1.5 官方 fp16 | 通用基线 | `Comfy-Org/stable-diffusion-v1-5-archive` → `v1-5-pruned-emaonly-fp16.safetensors` |
| Counterfeit V3.0 | 二次元 | `gsdf/Counterfeit-V3.0` → `Counterfeit-V3.0_fp32.safetensors` |

### 怎么下

**方式一：脚本**（本仓库自带，断点续传）

```powershell
# 下默认的 Animagine XL 4.0
powershell -ExecutionPolicy Bypass -File scripts\download_models.ps1 `
    -Models "C:\ComfyUI\models\checkpoints"

# 指定其它模型
... -Model illustrious
... -Model sd15
... -Model realvis
```

可用名：`illustrious` `noobai` `animagine` `pony` `realvis` `juggernaut` `sdxl-base`
`sd15` `counterfeit`

**方式二：浏览器**直链格式

```
https://huggingface.co/<仓库名>/resolve/main/<文件名>
```

例如：
`https://huggingface.co/Laxhar/noobai-XL-1.1/resolve/main/NoobAI-XL-v1.1.safetensors`

**放置位置**：`ComfyUI\models\checkpoints\`，单文件 `.safetensors` 直接放进去，
不用建子目录（ComfyUI 会读子目录，但没必要）。

> ⚠️ 别下 diffusers 格式（一堆 `unet/`、`vae/` 目录的那种）。要的是**单文件** checkpoint。
> HF 仓库里同一个模型的单文件通常在最外层，用上面的文件清单确认后再下。

---

## 五、LoRA：下载与加载

### 放哪

```
ComfyUI\models\loras\
├─ 直接放文件
└─ 或按风格分子目录（ComfyUI 列表里会显示成 子目录\文件名.safetensors）
```

放完在浏览器里按 **R** 刷新模型列表。

### 从哪下

| 来源 | 说明 |
|---|---|
| **Civitai** | 资源最全。多数模型需要登录态，直接浏览器点下载最省事；走 API 要带 token：`https://civitai.com/api/download/models/<版本ID>?token=<你的KEY>` |
| **HuggingFace** | 免登录，直链格式同上。适合找官方或热门 LoRA |

Civitai 的 API key 在 账号设置 → API Keys 生成，**别写进脚本提交到仓库**。

### 用哪个节点

| 节点 | 用途 | 输入输出 |
|---|---|---|
| **`LoraLoader`** | 从 checkpoint 出发时用（SD1.5 / SDXL 都是这种） | 吃 `MODEL` + `CLIP`，吐 `MODEL` + `CLIP` |
| `LoraLoaderModelOnly` | 只改 UNet、不动文本编码器（常见于加速/细节类 LoRA） | 只吃 `MODEL` |

接线（SDXL 标准链路）：

```
CheckpointLoaderSimple ─┬─ MODEL → LoraLoader → KSampler.model
                        ├─ CLIP  → LoraLoader → 两个 CLIPTextEncode.clip
                        └─ VAE   → VAEDecode.vae
```

**叠多个 LoRA 就串联**：上一个的 `MODEL`/`CLIP` 接到下一个的输入。顺序有影响，
一般「风格 → 角色 → 细节/加速」这样排。

### 两个强度参数

| 参数 | 作用 | 建议 |
|---|---|---|
| `strength_model` | 对画面的影响 | 0.6–0.8 起试；1.0 常常过冲 |
| `strength_clip` | 对提示词理解的影响 | 通常等于 model；风格 LoRA 可略低 |

### 三个必踩的坑

1. **基座必须匹配**：SDXL 的 LoRA 给 SD1.5 用会直接报维度错误或出废图。看 LoRA
   页面写的 base model 是 `SDXL 1.0` 还是 `SD 1.5`。
2. **触发词**：多数角色/风格 LoRA 需要特定触发词（如 `style_xxx`），不写等于没用。
   Civitai 页面或同目录的 `.txt` 里会写。
3. **这张卡的显存**：8 GB 上最多同时挂 1–2 个 LoRA。挂多了不是慢，是加载阶段就崩。

### 自带模板

`assets/workflow_sdxl_lora.json` 已经接好两级 LoRA 槽位，**默认旁路**
（节点 mode=4），不装 LoRA 也能直接跑；要用就把节点右键取消旁路、选文件。

---

## 六、参数（ZLUDA 环境专属）

**采样器只有这四个能用**，别照抄网上的 SDXL 教程：

| 项 | SDXL | SD1.5 |
|---|---|---|
| 步数 | 25（低于 20 出现色带） | 20 |
| CFG | 7 | 7 |
| 采样器 | **`dpmpp_2m`** 或 `euler_ancestral` | `euler` / `dpmpp_2m` |
| 调度器 | `karras`，想更快换 `beta` / `simple` | `simple` / `beta` |
| 分辨率 | 768² 稳；512² 最快；1024² 可能加载失败 | 512²–768² |

| 采样器 | 结果 |
|---|---|
| `euler` / `euler_ancestral` / `dpmpp_2m` / `ddim` | ✅ 可用（`ddim` 极慢，约 360 秒） |
| `dpmpp_sde` | ❌ 跑不完 |
| `unipc` | ❌ 该版本直接拒绝 |
| 调度器 | 六种全可用，`simple` / `beta` 最快 |

---

## 七、实测数据（SD1.5 / 512² / 含模型加载）

| 分辨率 | 20 步 |
|---|---|
| 256² | 20 秒 |
| 512² | 50 秒 |
| 640² | 75 秒 |
| 768² | 115 秒 |

SDXL 512² / 25 步 / `dpmpp_2m` + `karras`：**约 64 秒**，显存驻留约 4900 MB。

> 数据来自 Polaris 安装器作者的实测记录（RX 580 8GB），不是估算。
> 你的卡频率不同会有出入，但量级可信。

---

## 八、排错（按顺序查）

| 现象 | 原因与处理 |
|---|---|
| 杀软把 `zluda.exe` 删了 | 恢复并加排除，已知误报 |
| `LLVM ERROR: out of memory` | 主机内存不足，关掉其他程序重试 |
| `Could not find module ... cublas64_11.dll` | HIP SDK 没装或 PATH 不对，重跑 `setup.py` |
| `CUDNN_STATUS_INTERNAL_ERROR` | 必须带 `--disable-cudnn` 启动，用生成的 `run_zluda.bat` |
| 加载模型到一半进程消失、无报错 | **几乎都是主机内存不够**（需约 16 GB 提交内存），不是显卡问题 |
| 出图有严重色带 | 步数太低，SDXL 用 ≤ 4 步就会这样 |
| LoRA 加载后出废图 | 基座不匹配（SD1.5 LoRA 用在 SDXL 上），或强度 > 1 |
| `No module named venv` | 用了 ComfyUI 自带的 python_embeded，改用 python.org 的 3.12 |
| torch 下载卡住 | 网速低于 1 MB/s 会断。重跑 `setup.py`，它断点续传 |

---

## 九、什么时候别用这张卡

- 想跑 2026 年之后发布的新架构（3D VAE、大 DiT）→ **放弃**，换 12GB 以上 N 卡或 RDNA3
- 每天出几百张 → 单张 1 分钟，产出不够
- 高清修复 + ControlNet 叠加 → 显存余量不够，容易在加载阶段崩

一句话：**这张卡适合"能出图就行"的低频使用，不适合当生产力工具。**
