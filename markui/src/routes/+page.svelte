<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { fly } from 'svelte/transition';
	import * as THREE from 'three';
	import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader';

	let screen: HTMLCanvasElement;
	let polls = 0;

	let x = 50;
	let y = 50;
	let p = 0;
    let command = "";

	let pitch = 0;
	let yaw = 0;
	let opacity = -1;
	let pollMilliseconds = 20;

	const M = 50;
	const N = 50;

	let depthMap = new Uint8Array(M * N);
	let recencyMap = new Uint8Array(M * N);

	let scene3d: Element;
	let camera: THREE.PerspectiveCamera;
	let scene: THREE.Scene;
	let renderer: THREE.WebGLRenderer;
	let model: THREE.Object3D;
	const loader = new GLTFLoader();

    let pollInterval: NodeJS.Timeout;

	let laser = false;
	let automatic = false;

	let ready = false;

	function draw() {
		if (screen) {
			const ctx = screen.getContext('2d');

			// Draw the depthMap
			for (let i = 0; i < M; i++) {
				for (let j = 0; j < N; j++) {
					const value = depthMap[i + N * j];
                    const recency = recencyMap[i + N * j];
                    if (recency != 0) {
                        recencyMap[i + N * j] -= 5;
                    }

					// @ts-ignore
					ctx.fillStyle = `rgb(${value + recency}, ${value - recency/2}, ${value - recency/2})`;
					// @ts-ignore
					ctx.fillRect(
						j * (screen.width / N),
						i * (screen.height / M),
						screen.width / N,
						screen.height / M
					);
				}
			}
		}
	}

	async function pollData() {
		const response = await (await fetch('/')).json();
		x = response.x;
		y = response.y;
		p = response.p;
		depthMap[x + N * y] = 255 - p;
        recencyMap[x + N * y] = 0xff;
        pitch = (x - M/2) / M * 3.14;
        yaw = (y - N/2) / N * 3.14;
        draw();
		polls++;
	}

	function startPolling() {
		pollInterval = setInterval(pollData, pollMilliseconds);
	}

	onMount(() => {
		const h = scene3d.clientHeight;
		const w = scene3d.clientWidth;
		camera = new THREE.PerspectiveCamera(70, w / h, 0.1, 1000);
		scene = new THREE.Scene();

		renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
		renderer.setSize(w, h);
		scene3d.appendChild(renderer.domElement);

		loader.load(
			'/scene.gltf',
			function (gltf) {
				model = gltf.scene.children[0];
				scene.add(model);
			},
			undefined,
			function (error) {
				console.log(error);
			}
		);

		var light = new THREE.AmbientLight(0xffffff, 1);
		scene.add(light);

		camera.position.z = 2.5;
		camera.position.y = 1;
		camera.position.x = -0.03;
		camera.rotation.x = -0.3;

		animate();
		startPolling();

		ready = true;
	});

    onDestroy(() => {
        clearInterval(pollInterval);
    })

	function animate() {
		requestAnimationFrame(animate);

		if (opacity < 1) {
			opacity += 0.01;
		}

		// pitch += 0.005;
		yaw += 0.005;

		renderer.clear();
		renderer.render(scene, camera);
	}

	$: if (model) {
		model.rotation.x = pitch - 3.14 / 2;
	}
	$: if (model) {
		model.rotation.z = yaw;
	}

	enum Cmd {
		ScanAll = 0x0,
		ScanRow = 0x1,
		ScanCol = 0x2,
		MoveTo = 0x3, // Expects two more numbers
		ToggleLaser = 0x4,
		ToggleMode = 0x5,
	}

	function sendCommand() {

	}
</script>

<div class="custom-grid">
	<div class="col-start-1 row-start-1 text-center grid place-content-center h-full w-full">
		{#key ready}
			<h2 in:fly={{ x: 30, duration: 500, delay: 400 }}>Nicolás Nobili</h2>
		{/key}
		{#key ready}
			<h2 in:fly={{ x: 30, duration: 500, delay: 500 }}>Francisco Russo</h2>
		{/key}
	</div>
	<div class="col-start-2 row-start-1 text-center grid place-content-center h-full w-full">
		<h1>M.A.R.K. I</h1>
		{#key ready}
			<h2 in:fly={{ y: -30, duration: 500, delay: 300 }}>Multi Angle Radar Kinematics Mk.1</h2>
		{/key}
	</div>
	<div class="col-start-3 row-start-1 text-center grid place-content-center h-full w-full">
		{#key ready}
			<h2 in:fly={{ x: -30, duration: 500, delay: 400 }}>Facultad de Ingeniería de la UBA</h2>
		{/key}
		{#key ready}
			<h2 in:fly={{ x: -30, duration: 500, delay: 500 }}>Laboratorio de Microprocesadores</h2>
		{/key}
	</div>
	<div class="col-start-1 row-start-2 row-span-2 flex flex-col h-full w-full justify-evenly p-20">
		{#key ready}
			<button
				class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
				in:fly={{ x: 30, duration: 500, delay: 600 }}
			>
				Escanear todo
			</button>
		{/key}
		{#key ready}
			<button
				class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
				in:fly={{ x: 30, duration: 500, delay: 700 }}
			>
				Escanear horizontalmente
			</button>
		{/key}
		{#key ready}
			<button
				class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
				in:fly={{ x: 30, duration: 500, delay: 800 }}
			>
				Escanear verticalmente
			</button>
		{/key}
		{#key ready}
			<button
				class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
				in:fly={{ x: 30, duration: 500, delay: 900 }}
			>
				{laser ? 'Apagar' : 'Prender'} láser
			</button>
		{/key}
		{#key ready}
			<button
				class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
				in:fly={{ x: 30, duration: 500, delay: 1000 }}
			>
				Modo {automatic ? 'manual' : 'automático'}
			</button>
		{/key}
	</div>
	<div class="col-start-2 row-start-2 row-span-2 h-full w-full grid place-items-center p-20">
		<canvas class="h-full w-full" bind:this={screen} />
	</div>
	<div class="col-start-3 row-start-2 h-full w-full gird place-items-center p-20">
        <p class="text-lg">
            Frames: {polls}
            <br />
            Ángulo: {x}, {y}
            <br />
            Profundidad: {p}
            <br />
            Último comando enviado: {command}
        </p>
	</div>
	<div class="col-start-3 row-start-3 h-full w-full p-10">
		<div class="h-full w-full" bind:this={scene3d} />
	</div>
</div>

<style lang="postcss">
	@import url('https://fonts.googleapis.com/css2?family=Dosis:wght@500&family=Josefin+Sans&display=swap');

	:global(body) {
		font-family: 'Dosis', sans-serif;
		height: 100vh;
		width: 100vw;
		background-color: rgb(50, 50, 50);
		color: rgb(200, 200, 200);
	}

	h1 {
		font-size: 3.5rem;
		color: white;
	}

	h2 {
		font-size: 1.2rem;
	}

	.custom-grid {
		display: grid;
		grid-template-rows: 1fr 3fr 3fr;
		grid-template-columns: 3fr 4fr 3fr;
		gap: 5px;
		height: 100vh;
		width: 100vw;
		justify-items: center;
		align-items: center;
	}

	/* :global(*) {
    border: solid red;
} */
</style>
