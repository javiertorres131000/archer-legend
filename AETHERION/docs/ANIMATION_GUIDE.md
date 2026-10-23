# Contrato para etapa 3

Estado: pivotes creados, sin armature ni acciones. Los pivotes Root, Pelvis, LowerTorso, UpperTorso, Head, Shoulder_L/R, UpperArm_L/R, Forearm_L/R, Fist_L/R, Finger_L/R_0..3, Thumb_L/R, Thigh_L/R, Shin_L/R y Foot_L/R definen la jerarquía. Core, ChestPlate_-1/1, Halo_0..2, Cloth_L/R/Center y Fragment_XX son independientes.

La geometría de piedra debe permanecer rígida; una sola influencia por fragmento. Las telas tienen grupos Cloth_<nombre>_0..2 con pesos progresivos que se usarán para huesos de deformación. Los puños pueden trasladarse desde su pivote sin deformar las rocas; en el rig se preparará un controlador de separación.

Acciones previstas: Idle, EnergyBreath, FloatingRocks, Walk, Turn, Punch, DoublePunch, ColossusHammer, MeteorCharge, MeteorLaunch, CoreOpen, CoreBeam, GravityPrison, ShieldSummon, ShieldBreak, CelestialPillars, PhaseTransition, Stunned, Hit, Death. No están implementadas aún. El daño nunca dependerá de curvas de Blender: los marcadores se sincronizarán con tiempos de servidor.
