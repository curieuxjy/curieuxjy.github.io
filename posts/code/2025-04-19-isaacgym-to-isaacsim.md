---
title: "👩‍💻IsaacSim Migration from IsaacGym"
toc: true
number-sections: true
date: "2025-04-19"
description: 아까운 IsaacGym 기반 환경코드 IsaacSim으로 되살리기 
categories: [isaacsim, isaacgym, code]
execute:
  freeze: auto
---

# IsaacGymEnvs에서 마이그레이션

`IsaacGymEnvs`는 기존 `Isaac Gym Preview Release`를 위한 강화학습 프레임워크였으나, 현재는 두 프로젝트 모두 폐기(deprecated)되었습니다. 본 문서는 IsaacGymEnvs와 Isaac Lab의 주요 차이점과, Isaac Gym Preview Release와 Isaac Sim의 API 차이점에 대해 설명합니다.

## 작업 설정 (Task Config Setup)

IsaacGymEnvs에서는 작업 설정을 `.yaml` 파일로 정의했지만, Isaac Lab에서는 특별한 Python 클래스인 `@configclass`를 이용하여 설정합니다. 각 환경은 반드시 `envs.DirectRLEnvCfg`를 상속한 자체 설정 클래스를 만들어야 합니다.

예제:

```python
from isaaclab.envs import DirectRLEnvCfg
from isaaclab.scene import InteractiveSceneCfg
from isaaclab.sim import SimulationCfg

@configclass
class MyEnvCfg(DirectRLEnvCfg):
   # simulation
   sim: SimulationCfg = SimulationCfg()
   # robot
   robot_cfg: ArticulationCfg = ArticulationCfg()
   # scene
   scene: InteractiveSceneCfg = InteractiveSceneCfg()
   # env
   decimation = 2
   episode_length_s = 5.0
   action_space = 1
   observation_space = 4
   state_space = 0
   # task-specific parameters
   ...
```

## 시뮬레이션 설정 (Simulation Config)

시뮬레이션 관련 매개변수는 `SimulationCfg`를 통해 설정합니다. IsaacGymEnvs의 `substeps` 개념은 이제 `dt`와 `decimation`으로 대체됩니다.

예제:

```python
sim: SimulationCfg = SimulationCfg(
    device="cuda:0",
    dt=1/120,
    gravity=(0.0, 0.0, -9.81),
    physx=PhysxCfg(
        solver_type=1,
        max_position_iteration_count=4,
        max_velocity_iteration_count=0,
        bounce_threshold_velocity=0.2,
        gpu_max_rigid_contact_count=2**23
    )
)
```

:::: {.columns}

::: {.column width="50%"}

**Before**

```python
# IsaacGymEnvs
sim:

  dt: 0.0166 # 1/60 s
  substeps: 2
  up_axis: "z"
  use_gpu_pipeline: ${eq:${...pipeline},"gpu"}
  gravity: [0.0, 0.0, -9.81]
  physx:
    num_threads: ${....num_threads}
    solver_type: ${....solver_type}
    use_gpu: ${contains:"cuda",${....sim_device}}
    num_position_iterations: 4
    num_velocity_iterations: 0
    contact_offset: 0.02
    rest_offset: 0.001
    bounce_threshold_velocity: 0.2
    max_depenetration_velocity: 100.0
    default_buffer_size_multiplier: 2.0
    max_gpu_contact_pairs: 1048576 # 1024*1024
    num_subscenes: ${....num_subscenes}
    contact_collection: 0

```

:::

::: {.column width="50%"}
**After**


:::


::::


## 씬 설정 (Scene Config)

씬 설정은 `InteractiveSceneCfg`로 관리됩니다.

예제:

```python
scene: InteractiveSceneCfg = InteractiveSceneCfg(
    num_envs=512,
    env_spacing=4.0
)
```

## RL 설정 (RL Config Setup)

Isaac Lab에서도 여전히 rl_games 라이브러리 설정은 `.yaml` 파일로 작성합니다. 단, 관측과 행동의 클리핑(clipping) 범위는 RL 설정 파일로 이동합니다.

## 환경 생성 (Environment Creation)

Isaac Lab에서는 `create_sim()` 메서드 호출이 더 이상 필요하지 않습니다. 대신 `_setup_scene()`을 구현하여 씬 구성을 처리합니다.

예제:

```python
def _setup_scene(self):
    self.cartpole = Articulation(self.cfg.robot_cfg)
    spawn_ground_plane(prim_path="/World/ground", cfg=GroundPlaneCfg())
    self.scene.clone_environments(copy_from_source=False)
    self.scene.filter_collisions(global_prim_paths=[])
    self.scene.articulations["cartpole"] = self.cartpole
```

## 지상 평면 (Ground Plane)

지상 평면은 `TerrainImporterCfg` 클래스를 사용하여 정의합니다.

## 액터 (Actors)

액터 구성은 `ArticulationCfg` 클래스에서 관리하며, 자산(assets)의 USD 경로와 액추에이터(actuator) 설정 등을 포함합니다.

## 복제기 (Cloner)

Isaac Lab은 환경 복제를 위한 `Cloner` 개념을 도입하여 환경 생성을 간소화합니다.

## 시뮬레이션 상태 접근 (Accessing States)

Isaac Lab에서는 명시적 버퍼 래핑 및 언래핑 없이 직접 텐서로 데이터를 읽고 씁니다.

## 쿼터니언 관례 (Quaternion Convention)

Isaac Lab과 Isaac Sim은 `wxyz` 관례를 사용하며, IsaacGymEnvs의 `xyzw` 관례에서 전환이 필요합니다.

## 관절 순서 (Joint Order)

관절 순서는 Isaac Lab에서는 너비 우선(breadth-first)을 사용하며, IsaacGymEnvs의 깊이 우선(depth-first)과 다릅니다.

## 새 환경 생성 (Creating a New Environment)

Isaac Lab에서는 각 환경을 별도의 디렉토리로 구성하며, Gymnasium 인터페이스를 통해 등록합니다.

## 작업 로직 (Task Logic)

Isaac Lab에서는 작업 로직을 기본 클래스에서 자동으로 처리하며, 다음과 같은 순서를 따릅니다:

1. `_pre_physics_step()` 및 `_apply_action()`
2. `_get_dones()`
3. `_get_rewards()`
4. `_reset_idx()`
5. `_get_observations()`

## 학습 및 추론 실행 (Launching Training and Inferencing)

학습 실행:

```bash
python scripts/reinforcement_learning/rl_games/train.py --task=Isaac-Cartpole-Direct-v0 --headless
```

추론 실행:

```bash
python scripts/reinforcement_learning/rl_games/play.py --task=Isaac-Cartpole-Direct-v0 --num_envs=25 --checkpoint=<path/to/checkpoint>
```

이 외의 구체적인 API 예시와 코드 비교는 원문 문서를 참고하세요.



# Reference
- [IsaacSim 4.5.0 Documentation - From IsaacGymEnvs](https://isaac-sim.github.io/IsaacLab/main/source/migration/migrating_from_isaacgymenvs.html)