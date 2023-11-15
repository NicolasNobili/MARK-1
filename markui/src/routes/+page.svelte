<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { fade, fly } from "svelte/transition";
  import * as THREE from "three";
  import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader";
  import { tweened } from "svelte/motion";
  import { cubicOut } from "svelte/easing";
  import { browser } from "$app/environment";
  import { flip } from "svelte/animate";

  interface DataType {
    content: number[];
    id: number;
  }

  interface CommandType {
    content: number[];
    id: number;
  }

  // Transmission
  enum Cmd {
    Abort = "a",
    Ping = "b",
    ScanRow = "s",
    ScanCol = "t",
    ScanAll = "z",
    SingleMeasure = "m",
    AskPosition = "p",
    AskLaser = "l",
    TurnOnLaser = "c",
    TurnOffLaser = "d",
    MoveTo = "x", // Accompanied by 2 more bytes
    ScanRegion = "w", // Accompanied by 4 more bytes
    GetInfo = "i",
    WriteInfo = "h", // Accompanied by more bytes
  }

  // Reception
  enum Data {
    ScanDone = "f",
    Position = "p", // Expects 2 more numbers
    LaserOn = "j",
    LaserOff = "k",
    Measurement = "m", // Expects 4 more bytes
    Pong = "b",
    Debug = "o", // Expects 1 more number
    Busy = "n",
    What = "w",
    Info = "i", // More bytes, until \0
    InfoWriteDone = "h",
  }

  // Transmission of Data
  let tx_list: CommandType[] = [];
  let tx_idx = 0;
  let tx_buffer = "";
  let info_buffer = "";

  // Serial communication
  let port: any;
  let reader: any;
  const pollMilliseconds = 10;
  let pollInterval: number;
  let busy = false;
  const connectionDelay = 1; // ms

  // Reception of Data
  let rx_queue: number[] = [];
  let rx_list: DataType[] = [];
  let rx_idx = 0;
  let angle_fr = false;
  let laser_fr = false;

  // Angle A
  const N = 21;
  let x = Math.round(N / 2);
  let smoothx = tweened(x, { easing: cubicOut });
  $: $smoothx = x;
  $: yaw = ($smoothx / N - 0.5) * Math.PI;
  $: if (model) model.rotation.z = yaw;

  // Angle B
  const M = 21;
  let y = Math.round(M / 2);
  let smoothy = tweened(y, { easing: cubicOut });
  $: $smoothy = y;
  $: pitch = ($smoothy / M - 1) * Math.PI;
  $: if (model) model.rotation.x = pitch;

  // Measurement, depth
  let p: number | null = null;

  // Laser status
  let laser = false;

  // Depth Map
  let screen: HTMLCanvasElement;
  let depthMap = new Uint8Array(M * N);
  let recencyMap = new Uint8Array(M * N);
  let cursorPadding = 1;
  let animationFrame: null | number = null;

  // Screen controls
  let isDrawing = false;
  let startX = 0;
  let startY = 0;
  let currentX = 0;
  let currentY = 0;
  let endX = 0;
  let endY = 0;

  // 3D Model
  let scene3d: Element;
  let camera: THREE.PerspectiveCamera;
  let scene: THREE.Scene;
  let renderer: THREE.WebGLRenderer;
  let model: THREE.Object3D;
  const loader = new GLTFLoader();

  // Page load animations
  let ready = false;

  function to_bytes(s: string) {
    let bytes = [];

    for (let i = 0; i < s.length; i++) {
      bytes.push(s.charCodeAt(i));
    }

    return bytes;
  }

  function to_hex_string(n: number[]) {
    let hexAscii = [];

    for (let i = 0; i < n.length; i++) {
      const hexAsciiCharacter = n[i].toString(16).toUpperCase();
      const paddedHexAscii =
        hexAsciiCharacter.length === 1 ? "0" + hexAsciiCharacter : hexAsciiCharacter;
      hexAscii.push(paddedHexAscii);
    }

    return hexAscii.join(" ");
  }

  // Converts control characters to ␀, ␁, ␂, etc.
  function to_ascii(n: number[]) {
    let ascii = "";

    for (let i = 0; i < n.length; i++) {
      let charCode = n[i];
      if (charCode >= 0 && charCode <= 26) {
        charCode += 0x2400;
      }
      ascii += String.fromCharCode(charCode);
    }

    return ascii;
  }

  function getFinalCoordinates(event: MouseEvent) {
    const canvasRect = screen.getBoundingClientRect();
    const mouseX = event.clientX - canvasRect.left;
    const mouseY = event.clientY - canvasRect.top;

    // Calculate normalized coordinates (between 0 and 1)
    const normalizedX = mouseX / canvasRect.width;
    const normalizedY = mouseY / canvasRect.height;

    // Map normalized coordinates to your grid size (N and M)
    const gridX = Math.floor(normalizedX * N);
    const gridY = Math.floor(normalizedY * M);

    return {
      x: gridX,
      y: gridY,
    };
  }

  function handleMouseDown(event: MouseEvent) {
    if (!screen) {
      return;
    }

    isDrawing = true;
    ({ x: startX, y: startY } = getFinalCoordinates(event));
    ({ x: currentX, y: currentY } = getFinalCoordinates(event));
  }

  function handleMouseMove(event: MouseEvent) {
    if (!screen) {
      return;
    }

    ({ x: currentX, y: currentY } = getFinalCoordinates(event));
  }

  async function handleMouseUp(event: MouseEvent) {
    if (!screen) {
      return;
    }

    if (!isDrawing) {
      return;
    }

    isDrawing = false;
    if (busy || !port) {
      return;
    }
    ({ x: endX, y: endY } = getFinalCoordinates(event));

    // First, respect format from top left to bot right (lower to higher)
    if (startX > endX) {
      [startX, endX] = [endX, startX];
    }
    if (startY > endY) {
      [startY, endY] = [endY, startY];
    }

    // Check if only one point
    if (startX == endX && startY == endY) {
      await writeData(Cmd.MoveTo + String.fromCharCode(startX) + String.fromCharCode(startY));
      return;
    }

    // Else, scan region
    await writeData(
      Cmd.ScanRegion +
        String.fromCharCode(startX) +
        String.fromCharCode(startY) +
        String.fromCharCode(endX) +
        String.fromCharCode(endY),
    );
  }

  // Draws the depth map in the middle of the screen
  function draw() {
    if (!screen) {
      console.error("Cannot draw when screen is not available!");
    }

    const ctx = screen.getContext("2d");

    // Black background
    // // @ts-ignore
    // ctx.globalAlpha = 1.0;
    // // @ts-ignore
    // ctx.fillStyle = "rgb(0, 0, 0)";
    // // @ts-ignore
    // ctx.fillRect(0, 0, screen.width, screen.height);

    for (let i = 0; i < M; i++) {
      for (let j = 0; j < N; j++) {
        // Read buffers
        const value = depthMap[i + N * j];
        const recency = recencyMap[i + N * j];
        if (recency != 0) {
          recencyMap[i + N * j] -= 1;
        }

        // Draw depth square
        // @ts-ignore
        ctx.fillStyle = `rgb(${value + recency}, ${value - recency / 2}, ${value - recency / 2})`;
        // @ts-ignore
        ctx.fillRect(
          i * (screen.width / N),
          j * (screen.height / M),
          screen.width / N,
          screen.height / M,
        );

        // Draw cursor
        if (angle_fr) {
          // @ts-ignore
          // ctx.globalAlpha = 0.1;
          // @ts-ignore
          ctx.fillStyle = "rgb(0, 100, 255)";
          // @ts-ignore
          ctx.fillRect(
            $smoothx * (screen.width / N) + cursorPadding,
            $smoothy * (screen.height / M) + cursorPadding,
            screen.width / N - 2 * cursorPadding,
            screen.height / M - 2 * cursorPadding,
          );
        }

        // Draw selection
        if (isDrawing) {
          const selectionWidth = (Math.max(1, currentX - startX + 1) / N) * screen.width;
          const selectionHeight = (Math.max(1, currentY - startY + 1) / M) * screen.height;
          // @ts-ignore
          ctx.fillStyle = "rgb(50, 100, 50)";
          // @ts-ignore
          ctx.fillRect(
            startX * (screen.width / N),
            startY * (screen.height / M),
            selectionWidth,
            selectionHeight,
          );
        }
      }
    }
  }

  // Flushes RX as much as possible
  // If there is an incomplete command, it leaves it there
  async function flush_rx_queue() {
    while (rx_queue.length > 0) {
      const data_type = String.fromCharCode(rx_queue[0]);
      const len = rx_queue.length;
      let bytes_to_flush = 0;

      switch (data_type) {
        case Data.Measurement:
          if (len >= 5) {
            bytes_to_flush = 5;
            x = rx_queue[1];
            y = rx_queue[2];
            p = rx_queue[4]; // + rx_queue[3] / 255; (doesn't matter)
            depthMap[x + N * y] = 255 - p;
            recencyMap[x + N * y] = 255;
            angle_fr = true;
          }
          break;

        case Data.Position:
          if (len >= 3) {
            bytes_to_flush = 3;
            x = rx_queue[1];
            y = rx_queue[2];
            p = null;
            angle_fr = true;
          }
          break;

        case Data.ScanDone:
          bytes_to_flush = 1;
          break;

        case Data.LaserOn:
          bytes_to_flush = 1;
          laser = true;
          laser_fr = true;
          break;

        case Data.LaserOff:
          bytes_to_flush = 1;
          laser = false;
          laser_fr = true;
          break;

        case Data.Pong:
          bytes_to_flush = 1;
          break;

        case Data.Debug:
          if (len >= 2) {
            bytes_to_flush = 2;
          }
          break;

        case Data.Busy:
          bytes_to_flush = 1;
          break;

        case Data.What:
          bytes_to_flush = 1;
          break;

        case Data.Info:
          // Find null character
          const idx = rx_queue.indexOf(0);
          if (idx >= 0) {
            busy = false;
            bytes_to_flush = idx + 1;
          }
          break;

        case Data.InfoWriteDone:
          bytes_to_flush = 1;
          break;

        default:
          // Unknown command, just get rid of it
          bytes_to_flush = 1;
      }

      if (bytes_to_flush === 0) {
        break;
      }

      const new_rx = {
        content: rx_queue.slice(0, bytes_to_flush),
        id: rx_idx,
      };
      rx_idx++;
      rx_list = [new_rx, ...rx_list];
      if (rx_list.length > 6) {
        rx_list.pop();
      }
      rx_queue = rx_queue.slice(bytes_to_flush);
    }
  }

  // Connect or disconnect to serial port
  async function toggleConection() {
    if (!port) {
      try {
        busy = true;
        // @ts-ignore
        port = await navigator.serial.requestPort();
        await port.open({ baudRate: 9600 });
        setTimeout(async () => {
          await writeData(Cmd.AskPosition);
          await writeData(Cmd.AskLaser);
          await writeData(Cmd.GetInfo);
          busy = false; // TODO: true
          reader = port.readable.getReader();
          pollInterval = setInterval(readData, pollMilliseconds);
        }, connectionDelay);
      } catch (error) {
        if (error instanceof Error) {
          alert(error.name + ": " + error.message);
        }
        port = null;
        busy = false;
      }
    } else {
      clearInterval(pollInterval);

      try {
        // Release the lock on the reader before closing the port
        if (reader) {
          await reader.cancel();
          reader = null;
        }

        await port.close();
      } catch (error) {
        if (error instanceof Error) {
          alert(error.name + ": " + error.message);
        }
      }

      port = null;
      p = null;
      laser_fr = false;
      angle_fr = false;
    }
  }

  // Send data over the serial port
  async function writeData(cmd: string, ending_null: boolean = false) {
    const bytes_cmd = to_bytes(cmd);
    if (ending_null) {
      bytes_cmd.push(0);
    }
    if (!port) {
      console.error("Cannot write on closed port!");
      return;
    }
    const new_tx = {
      content: bytes_cmd,
      id: tx_idx,
    };
    tx_idx++;
    tx_list = [new_tx, ...tx_list];
    if (tx_list.length > 6) {
      tx_list.pop();
    }
    const encoder = new TextEncoder();
    console.log("Enviado: " + cmd);
    const writer = port.writable.getWriter();
    await writer.write(new Uint8Array(bytes_cmd));
    writer.releaseLock();
  }

  // Read data over the serial port
  async function readData() {
    if (!reader) {
      console.log("Reader disconnected!");
      return;
    }

    try {
      const readerData = await reader.read();
      if (readerData.done) {
        console.log("Recepción finalizada!");
      } else {
        const readBytes = Array.from(readerData.value) as number[];
        console.log("Recibido: " + to_ascii(readBytes));
        rx_queue = [...rx_queue, ...readBytes];
        flush_rx_queue();
      }
    } catch (err) {
      const errorMessage = `error reading data: ${err}`;
      console.error(errorMessage);
      return errorMessage;
    }
  }

  // Ask for laser if necessary. Turn on or off.
  async function toggleLaser() {
    if (laser_fr) {
      if (laser) {
        await writeData(Cmd.TurnOffLaser);
      } else {
        await writeData(Cmd.TurnOnLaser);
      }
    } else {
      await writeData(Cmd.AskLaser);
    }
  }

  // Send three bytes (MoveTo, StepA, StepB)
  async function sendMoveTo(event: MouseEvent) {
    if (!port) {
      return;
    }

    if (screen) {
      const canvasRect = screen.getBoundingClientRect();
      const mouseX = event.clientX - canvasRect.left;
      const mouseY = event.clientY - canvasRect.top;

      // Calculate normalized coordinates (between 0 and 1)
      const normalizedX = mouseX / canvasRect.width;
      const normalizedY = mouseY / canvasRect.height;

      // Map normalized coordinates to your grid size (N and M)
      const gridX = Math.floor(normalizedX * N);
      const gridY = Math.floor(normalizedY * M);

      // Send the MoveTo command and coordinates to your device
      await writeData(Cmd.MoveTo + String.fromCharCode(gridX) + String.fromCharCode(gridY));
    }
  }

  // Frame rendering for drawing in the middle and 3D model
  function animate() {
    animationFrame = requestAnimationFrame(animate);

    renderer.clear();
    renderer.render(scene, camera);

    draw();
  }

  // Setup
  onMount(() => {
    if (!browser) {
      return;
    }

    // 3D model stuff
    const h = scene3d.clientHeight;
    const w = scene3d.clientWidth;
    camera = new THREE.PerspectiveCamera(70, w / h, 0.1, 1000);
    scene = new THREE.Scene();

    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setSize(w, h);
    scene3d.appendChild(renderer.domElement);
    const opacity = tweened(0);

    loader.load(
      "/scene.gltf",
      function (gltf) {
        model = gltf.scene.children[0];
        model.traverse((child) => {
          if (child instanceof THREE.Mesh && child.material) {
            child.material.transparent = true;
            opacity.subscribe((value) => {
              child.material.opacity = value;
            });
          }
        });
        scene.add(model);
      },
      undefined,
      function (error) {
        console.log(error);
      },
    );

    opacity.set(1, { delay: 1200, duration: 500 });

    var light = new THREE.AmbientLight(0xffffff, 1);
    scene.add(light);

    camera.position.z = 2.5;
    camera.position.y = 1;
    camera.position.x = -0.03;
    camera.rotation.x = -0.3;

    animate();

    // Ready to make intro transitions
    ready = true;
  });

  onDestroy(() => {
    if (browser) {
      if (animationFrame) {
        cancelAnimationFrame(animationFrame);
      }
      if (port) {
        toggleConection();
      }
    }
  });
</script>

<div class="custom-grid">
  <div class="col-start-1 row-start-1 text-center grid place-content-center h-full w-full">
    {#key ready}
      <h2 in:fly={{ x: 30, duration: 500, delay: 400 }}>Nicolás Nobili</h2>

      <h2 in:fly={{ x: 30, duration: 500, delay: 500 }}>Francisco Russo</h2>
    {/key}
  </div>

  <div class="col-start-2 row-start-1 text-center grid place-content-center h-full w-full">
    <h1>M.A.R.K. I</h1>
    {#key ready}
      <h2 in:fly={{ y: -30, duration: 500, delay: 300 }}>Multi Angle Radar Kinematics Mk.1</h2>
    {/key}
  </div>

  <div
    class="col-start-3 col-span-6 row-start-1 text-center grid place-content-center h-full w-full"
  >
    {#key ready}
      <h2 in:fly={{ x: -30, duration: 500, delay: 400 }}>Facultad de Ingeniería de la UBA</h2>

      <h2 in:fly={{ x: -30, duration: 500, delay: 500 }}>Laboratorio de Microprocesadores</h2>
    {/key}
  </div>

  <div class="col-start-1 row-start-2 row-span-2 flex flex-col h-full w-full justify-evenly p-20">
    {#key ready}
      <button
        on:click={toggleConection}
        class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
        in:fly={{ x: 30, duration: 500, delay: 600 }}
      >
        {port ? "Desconectar" : "Conectar"}
      </button>

      <div
        in:fly={{ x: 30, duration: 500, delay: 700 }}
        class="flex flex-row justify-between gap-1"
      >
        <button
          disabled={!port || busy}
          on:click={() => writeData(Cmd.ScanAll)}
          class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12 w-full leading-none"
        >
          Escanear todo
        </button>

        <button
          disabled={!port || busy}
          on:click={() => writeData(Cmd.ScanRow)}
          class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12 w-full leading-none"
        >
          Escanear fila
        </button>

        <button
          disabled={!port || busy}
          on:click={() => writeData(Cmd.ScanCol)}
          class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12 w-full leading-none"
        >
          Escanear columna
        </button>
      </div>

      <button
        disabled={!port || busy}
        on:click={() => writeData(Cmd.SingleMeasure)}
        class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
        in:fly={{ x: 30, duration: 500, delay: 800 }}
      >
        Medir en posición actual
      </button>

      <button
        disabled={!port || busy}
        on:click={toggleLaser}
        class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
        in:fly={{ x: 30, duration: 500, delay: 900 }}
      >
        {laser_fr ? (laser ? "Apagar" : "Prender") : "Consultar"} láser
      </button>

      <button
        disabled={!port || busy}
        on:click={() => writeData(Cmd.Abort)}
        class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
        in:fly={{ x: 30, duration: 500, delay: 1000 }}
      >
        Cancelar acción
      </button>

      <button
        disabled={!port || busy}
        on:click={() => {
          writeData(Cmd.GetInfo);
          busy = true;
        }}
        class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12"
        in:fly={{ x: 30, duration: 500, delay: 1100 }}
      >
        Pedir información
      </button>

      <div
        in:fly={{ x: 30, duration: 500, delay: 1200 }}
        class="flex flex-row justify-between gap-1"
      >
        <input
          bind:value={info_buffer}
          disabled={!port || busy}
          class="focus:outline-none text-gray-800 font-mono w-full p-2 border-rose-900 rounded-md border-4 bg-gray-200 focus:bg-gray-50 transition-colors"
          type="text"
          on:keydown={(event) => {
            if (event.key === "Enter") {
              // Prevent the default behavior of the Enter key (form submission)
              event.preventDefault();

              // Trigger the "ENVIAR" button click
              if (port && info_buffer.length > 0) {
                writeData(Cmd.WriteInfo + info_buffer, true);
                info_buffer = "";
              }
            }
          }}
        />
        <button
          disabled={!port || info_buffer.length === 0 || busy}
          on:click={() => {
            writeData(Cmd.WriteInfo + info_buffer, true);
            info_buffer = "";
          }}
          class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12 leading-none px-2"
        >
          Escribir información
        </button>
      </div>

      <div
        in:fly={{ x: 30, duration: 500, delay: 1300 }}
        class="flex flex-row justify-between gap-1"
      >
        <input
          bind:value={tx_buffer}
          disabled={!port}
          class="focus:outline-none text-gray-800 font-mono w-full p-2 border-rose-900 rounded-md border-4 bg-gray-200 focus:bg-gray-50 transition-colors"
          type="text"
          on:keydown={(event) => {
            if (event.key === "Enter") {
              // Prevent the default behavior of the Enter key (form submission)
              event.preventDefault();

              // Trigger the "ENVIAR" button click
              if (port && tx_buffer.length > 0) {
                writeData(tx_buffer);
                tx_buffer = "";
              }
            }
          }}
        />
        <button
          disabled={!port || tx_buffer.length === 0}
          on:click={() => {
            writeData(tx_buffer);
            tx_buffer = "";
          }}
          class="rounded-md p-1 text-xl bg-rose-900 hover:bg-rose-800 transition-colors h-12 leading-none px-2"
        >
          Enviar
        </button>
      </div>
    {/key}
  </div>

  <div class="col-start-2 row-start-2 row-span-2 h-full w-full grid place-items-center py-20 px-5">
    <canvas
      class="h-full w-full"
      bind:this={screen}
      on:mousedown={handleMouseDown}
      on:mouseup={handleMouseUp}
      on:mousemove={handleMouseMove}
    />
  </div>

  <div
    class="col-start-3 col-span-2 row-start-3 h-full w-full pb-20 pt-5 flex flex-col justify-evenly"
  >
    {#key ready}
      <p class="text-lg" in:fly={{ x: -30, duration: 500, delay: 800 }}>
        <span class="underline">Ángulo A:</span>
        {angle_fr ? x : ""}
      </p>
      <p class="text-lg" in:fly={{ x: -30, duration: 500, delay: 850 }}>
        <span class="underline">Ángulo B:</span>
        {angle_fr ? y : ""}
      </p>
      <p class="text-lg" in:fly={{ x: -30, duration: 500, delay: 900 }}>
        <span class="underline">Última medición:</span>
        {p ? p : ""}
      </p>
      <p class="text-lg" in:fly={{ x: -30, duration: 500, delay: 950 }}>
        <span class="underline">Láser:</span>
        {laser_fr ? (laser ? "Prendido" : "Apagado") : ""}
      </p>
    {/key}
  </div>

  {#key ready}
    <div
      class="col-start-3 col-span-3 row-start-2 h-full w-full pt-20 gap-2 flex flex-col items-middle text-center overflow-hidden"
      in:fly={{ x: -30, duration: 500, delay: 600 }}
    >
      <h2 class="underline">TX</h2>
      {#each tx_list as tx (tx.id)}
        <div
          class="flex justify-center items-center gap-2"
          animate:flip={{ duration: 100 }}
          in:fade={{ duration: 150 }}
          out:fade={{ duration: 50 }}
        >
          <span class="font-mono">{to_ascii(tx.content)}</span>
          <span class="px-1 py-0.5 bg-gray-800 text-white rounded inline-block text-sm"
            >{to_hex_string(tx.content)}</span
          >
        </div>
      {/each}
    </div>
  {/key}

  {#key ready}
    <div
      class="col-start-6 col-span-3 row-start-2 h-full w-full pt-20 gap-2 flex flex-col items-middle text-center overflow-hidden"
      in:fly={{ x: -30, duration: 500, delay: 800 }}
    >
      <h2 class="underline">RX</h2>
      {#each rx_list as rx (rx.id)}
        <div
          class="flex justify-center items-center gap-2"
          animate:flip={{ duration: 100 }}
          in:fade={{ duration: 150 }}
          out:fade={{ duration: 50 }}
        >
          <span class="font-mono">{to_ascii(rx.content)}</span>
          <span class="px-1 py-0.5 bg-gray-800 text-white rounded inline-block text-sm"
            >{to_hex_string(rx.content)}</span
          >
        </div>
      {/each}
    </div>
  {/key}

  <!--div class="col-start-4 row-start-2 h-full w-full pt-20">
    {#key ready}
      <p class="text-lg" in:fly={{ x: -30, duration: 500, delay: 900 }}>
        <span class="underline">Último comando enviado:</span>
        <span class="font-mono">{ascii_to_pictures(tx)}</span>
        <span class="px-1 py-0.5 bg-gray-800 text-white rounded inline-block text-sm"
          >{string_to_hex_string(tx)}</span
        >
      </p>
      <p class="text-lg" in:fly={{ x: -30, duration: 500, delay: 1000 }}>
        <span class="underline">Último dato recibido:</span>
        <span class="font-mono">{ascii_to_pictures(rx)}</span>
        <span class="px-1 py-0.5 bg-gray-800 text-white rounded inline-block text-sm"
          >{string_to_hex_string(rx)}</span
        >
      </p>
      <p class="text-lg" in:fly={{ x: -30, duration: 500, delay: 1100 }}>
        <span class="underline">Último debug:</span>
        <span class="font-mono">{ascii_to_pictures(debug)}</span>
        <span class="px-1 py-0.5 bg-gray-800 text-white rounded inline-block text-sm"
          >{string_to_hex_string(debug)}</span
        >
      </p>
      <p class="text-lg" in:fly={{ x: -30, duration: 500, delay: 1200 }}>
        <span class="underline">Cola de lectura:</span>
        <span class="font-mono">{ascii_to_pictures(rx_queue)}</span><span
          class="px-1 py-0.5 bg-gray-800 text-white rounded inline-block text-sm"
          >{string_to_hex_string(rx_queue)}</span
        >
      </p>
    {/key}
  </div-->

  <div class="col-start-5 col-span-4 row-start-3 h-full w-full pb-20 px-5">
    <div class="h-full w-full" bind:this={scene3d} />
  </div>
</div>

<style lang="postcss">
  @import url("https://fonts.googleapis.com/css2?family=Dosis:wght@500&family=Josefin+Sans&display=swap");

  :global(body) {
    font-family: "Dosis", sans-serif;
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
    grid-template-columns: 6fr 6fr 1fr 1fr 1fr 1fr 1fr 1fr;
    gap: 5px;
    height: 100vh;
    width: 100vw;
    justify-items: center;
    align-items: center;
  }

  button:disabled {
    background-color: indianred;
  }

  input:disabled {
    border-color: indianred;
    background-color: rgb(150, 150, 150);
  }

  /* :global(*) {
    border: solid red;
} */
</style>
