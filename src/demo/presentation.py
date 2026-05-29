#!/usr/bin/env python3
import sys
import time

try:
    from rich.console import Console
    from rich.layout import Layout
    from rich.panel import Panel
    from rich.table import Table
    from rich.text import Text
    from rich.live import Live
    from rich.align import Align
    from rich.syntax import Syntax
    from rich.style import Style
    from rich import box
except ImportError:
    print("\n\033[1;31m[!] Missing External Library: 'rich'\033[0m")
    print("This spectacular academic demo requires the 'rich' python library for advanced 2D animations.")
    print("\033[1;32mPlease run: pip install rich\033[0m\n")
    sys.exit(1)

console = Console()

# =========================================================
# PHASE 1: ARCHITECTURE STATE & LOGIC
# =========================================================
class ArchState:
    def __init__(self):
        self.step = 0
        self.header_title = "[bold white]PHASE 1: Project Architecture Walkthrough[/]"
        self.arch_colors = {
            "driver": "dim white",
            "mlir": "dim white",
            "runtime": "dim white"
        }
        self.code_title = "[dim]Code[/]"
        self.code_content = ""
        self.code_lang = "cpp"
        self.explanation = ""

    def render_arch(self):
        diagram = f"""
 [bold]LLVM / FLANG COMPILATION PIPELINE[/]

      ┌───────────────────────┐
      │     Fortran Source    │
      └───────────┬───────────┘
                  │
      ┌───────────▼───────────┐
      │   [{self.arch_colors['driver']}]1. Flang Driver[/]     │
      │  [{self.arch_colors['driver']}](CompilerInvocation)[/] │
      └───────────┬───────────┘
                  │ (AST Generation)
      ┌───────────▼───────────┐
      │   [{self.arch_colors['mlir']}]2. HLFIR Dialect[/]     │
      │  [{self.arch_colors['mlir']}](Instrumentation Pass)[/]│
      └───────────┬───────────┘
                  │ (Lowering & Linking)
      ┌───────────▼───────────┐
      │   [{self.arch_colors['runtime']}]3. C++ Runtime[/]       │
      │  [{self.arch_colors['runtime']}](Bounds Trap Handler)[/] │
      └───────────┬───────────┘
                  │
      ┌───────────▼───────────┐
      │    Executable Binary  │
      └───────────────────────┘
"""
        return Panel(Text.from_markup(diagram), title="[bold cyan]System Architecture[/]", border_style="cyan", box=box.ROUNDED)

    def render_code(self):
        syntax = Syntax(self.code_content, self.code_lang, theme="monokai", line_numbers=True, word_wrap=True)
        return Panel(syntax, title=self.code_title, border_style="green", box=box.ROUNDED)

    def render_explanation(self):
        return Panel(Text.from_markup(self.explanation), title="[bold yellow]Component Explanation[/]", border_style="yellow")

    def render(self):
        layout = Layout()
        layout.split_column(
            Layout(name="header", size=3),
            Layout(name="main", ratio=2),
            Layout(name="footer", size=8)
        )
        layout["main"].split_row(
            Layout(name="arch", ratio=1),
            Layout(name="code", ratio=2)
        )

        header_text = Align.center(Text.from_markup(self.header_title))
        layout["header"].update(Panel(header_text, style="on dark_blue"))
        layout["arch"].update(self.render_arch())
        layout["code"].update(self.render_code())
        layout["footer"].update(self.render_explanation())
        
        return layout

# =========================================================
# PHASE 2: RAM DEMO STATE & LOGIC
# =========================================================
CODE_LINES = [
    "program bounds_demo",
    "  implicit none",
    "  integer, parameter :: N = 5",
    "  real*8, allocatable :: A(:)",
    "",
    "  ! Allocate array of size 5",
    "  allocate(A(N))",
    "",
    "  ! Valid Memory Access",
    "  A(3) = 99.9",
    "",
    "  ! Out-of-Bounds Memory Access",
    "  A(6) = 66.6",
    "",
    "end program bounds_demo"
]

class RamDemoState:
    def __init__(self):
        self.code_line = 0
        self.ptr_pos = -1
        self.values = ["0.0"] * 8
        self.shield_active = False
        self.is_corrupted = False
        self.is_flashing = False
        self.log_messages = []
        self.status_header = "[bold white]Awaiting Execution...[/]"
        self.terminal_output = ""

    def log(self, msg):
        self.log_messages.append(msg)
        if len(self.log_messages) > 6:
            self.log_messages.pop(0)

    def render_code(self):
        txt = Text()
        for i, line in enumerate(CODE_LINES):
            if i == self.code_line:
                txt.append(f"> {line}\n", style="bold black on yellow")
            else:
                if line.strip().startswith("!"):
                    txt.append(f"  {line}\n", style="dim green")
                elif "allocate" in line or "program" in line:
                    txt.append(f"  {line}\n", style="bold cyan")
                else:
                    txt.append(f"  {line}\n", style="white")
        return Panel(txt, title="[bold blue]Fortran Source Code[/]", border_style="blue", box=box.ROUNDED)

    def render_ram(self):
        table = Table(show_header=True, header_style="bold magenta", box=box.SIMPLE_HEAVY, expand=True)
        
        for i in range(1, 9):
            if i <= 5:
                table.add_column(f"A({i})\n0x10{i*4:02X}", justify="center")
            else:
                table.add_column(f"??({i})\n0x10{i*4:02X}", justify="center", style="dim")

        row = []
        for i in range(8):
            val = self.values[i]
            if self.is_flashing and i == self.ptr_pos:
                style = "bold white on red"
            elif self.is_corrupted and i >= 5:
                style = "bold red"
            elif self.shield_active and i < 5:
                style = "bold cyan on dark_blue"
            elif i >= 5:
                style = "dim white"
            else:
                style = "bold white"
            row.append(f"[{style}] {val} [/]")
        table.add_row(*row)

        ptr_row = []
        for i in range(8):
            if i == self.ptr_pos:
                if self.is_flashing:
                    ptr_row.append("[bold red]↑ PTR[/]")
                elif self.shield_active and i >= 5:
                    ptr_row.append("[bold orange1]↑ BLOCKED[/]")
                else:
                    ptr_row.append("[bold yellow]↑ PTR[/]")
            else:
                ptr_row.append("")
        table.add_row(*ptr_row)

        border_color = "cyan" if self.shield_active else ("red" if self.is_corrupted else "white")
        title = "[bold cyan]MLIR SANITIZER SHIELD ACTIVE[/]" if self.shield_active else "[bold white]STANDARD RAM ALLOCATION[/]"
        
        return Panel(Align.center(table), title=title, border_style=border_color)

    def render_logs(self):
        txt = Text("\n".join(self.log_messages))
        return Panel(txt, title="[bold green]System Trace[/]", border_style="green", height=8)

    def render_terminal(self):
        return Panel(Text.from_markup(self.terminal_output), title="[bold white]Compiler Output[/]", border_style="white", height=12)

    def render(self):
        layout = Layout()
        layout.split_column(
            Layout(name="header", size=3),
            Layout(name="main", ratio=1),
            Layout(name="footer", size=12)
        )
        layout["main"].split_row(
            Layout(name="code", ratio=1),
            Layout(name="ram", ratio=2)
        )
        layout["footer"].split_row(
            Layout(name="logs", ratio=1),
            Layout(name="terminal", ratio=2)
        )

        header_text = Align.center(Text.from_markup(self.status_header))
        layout["header"].update(Panel(header_text, style="on dark_blue"))
        layout["code"].update(self.render_code())
        layout["ram"].update(self.render_ram())
        layout["logs"].update(self.render_logs())
        layout["terminal"].update(self.render_terminal())
        
        return layout

# =========================================================
# UNIFIED RUNNER
# =========================================================
def wait_for_enter(live_ctx, state, msg=">>> Press ENTER to advance..."):
    if hasattr(state, 'header_title'):
        state.header_title = f"[blink bold yellow]{msg}[/]"
    else:
        state.status_header = f"[blink bold yellow]{msg}[/]"
    live_ctx.update(state.render())
    input()
    if hasattr(state, 'header_title'):
        state.header_title = "[bold white]Loading...[/]"
    else:
        state.status_header = "[bold white]Executing...[/]"
    live_ctx.update(state.render())

def run_unified_presentation():
    console.clear()
    
    # ---------------------------------------------------------
    # PHASE 1: ARCHITECTURE
    # ---------------------------------------------------------
    state_arch = ArchState()
    with Live(state_arch.render(), refresh_per_second=30, screen=True) as live:
        
        state_arch.explanation = "Welcome to the Unified Architecture & Execution Walkthrough.\nWe will first trace the journey of an array access through the LLVM compiler.\nThen, we will simulate the physical memory execution."
        state_arch.code_title = "[dim]No File Selected[/]"
        state_arch.code_content = "! Awaiting selection..."
        state_arch.code_lang = "fortran"
        live.update(state_arch.render())
        wait_for_enter(live, state_arch, ">>> Press ENTER to explore the Flang Driver...")

        # STEP 1: Driver
        state_arch.header_title = "[bold white]Analyzing: The Flang Driver[/]"
        state_arch.arch_colors["driver"] = "bold green"
        state_arch.code_title = "[bold green]src/driver/FlangDriverIntegration.patch[/]"
        state_arch.code_lang = "diff"
        state_arch.code_content = """--- a/flang/lib/Optimizer/Passes/Pipelines.cpp
+++ b/flang/lib/Optimizer/Passes/Pipelines.cpp
@@ -100,6 +100,9 @@ void createHLFIRToFIRPassPipeline(...) {
   // Add our custom bounds sanitizer pass BEFORE lowering to FIR
+  if (EnableBoundsCheck) {
+    pm.addPass(fir::createHLFIRBoundsCheckPass());
+  }
   pm.addPass(hlfir::createLowerHLFIRIntrinsics());"""
        state_arch.explanation = "[bold]The Gateway:[/] This patch modifies the Flang frontend driver.\nIt detects the `-fcheck=bounds` flag from the user and tells the MLIR Pass Manager to inject our custom `HLFIRBoundsCheckPass` precisely before HLFIR operations are destroyed and lowered to basic FIR."
        live.update(state_arch.render())
        wait_for_enter(live, state_arch, ">>> Press ENTER to explore the MLIR Pass...")

        # STEP 2: MLIR Pass
        state_arch.arch_colors["driver"] = "dim white"
        state_arch.arch_colors["mlir"] = "bold magenta"
        state_arch.code_title = "[bold magenta]src/pass/BoundsCheckInstrumentation.cpp[/]"
        state_arch.code_lang = "cpp"
        state_arch.code_content = """// 1. Find hlfir.designate array access
Value idx = indices[dim];

// 2. Extract bounds from HLFIR semantic metadata
Value lowerBound = shapeShiftOp.getOperands()[dim * 2];
Value extent = shapeShiftOp.getOperands()[dim * 2 + 1];

// 3. Inject MLIR logical checks safely
if (!idx.getType().isIntOrIndex()) continue; // Defensive QA
Value dimOOB = builder.create<arith::OrIOp>(loc, tooLow, tooHigh);

// 4. Wrap runtime call in an scf.if block
builder.create<scf::IfOp>(loc, dimOOB, false, [&](OpBuilder &ifB, Location ifL) {
    ifB.create<func::CallOp>(ifL, "_FortranABoundsCheck", ...);
});"""
        state_arch.explanation = "[bold]The Core Brain:[/] This C++ pass runs at compile-time over the MLIR tree.\nIt hunts for `hlfir.designate` (array access) operations. Because we intercept it at the HLFIR level, we still have access to rich Fortran metadata (extents/shapes).\nIt surgically injects an `if (out_of_bounds)` block into the Intermediate Representation."
        live.update(state_arch.render())
        wait_for_enter(live, state_arch, ">>> Press ENTER to explore the C++ Runtime...")

        # STEP 3: Runtime
        state_arch.arch_colors["mlir"] = "dim white"
        state_arch.arch_colors["runtime"] = "bold cyan"
        state_arch.code_title = "[bold cyan]src/runtime/bounds-check.cpp[/]"
        state_arch.code_lang = "cpp"
        state_arch.code_content = """extern "C" {
void _FortranABoundsCheck(int64_t index, int64_t lb, int64_t ub,
                          int32_t dim, const char *varName, ...) {
  // If the index is within bounds, simply return (hot path).
  if (index >= lb && index <= ub) return;

  // POSIX thread-safe formatting
  fprintf(stderr,
          "\\n\\033[1;31m=======================================\\033[0m\\n"
          "\\033[1;31m  HLFIR BOUNDS VIOLATION DETECTED      \\033[0m\\n"
          "  Variable: %s | Access: %lld | Valid: [%lld:%lld]\\n",
          varName, index, lb, ub);

  // Safely kill the execution
  Fortran::runtime::Terminator terminator{fileName, line};
  terminator.Crash("Array bounds violation detected.");
}
}"""
        state_arch.explanation = "[bold]The Execution Trap:[/] This library is linked into the final binary.\nIf the MLIR `scf.if` condition triggers at runtime, this C++ function is called.\nIt prints the ANSI diagnostic and uses Flang's internal `Terminator` to safely halt the program, preventing memory corruption."
        live.update(state_arch.render())
        wait_for_enter(live, state_arch, ">>> Press ENTER to begin Phase 2: Live Memory Simulation...")

    # ---------------------------------------------------------
    # PHASE 2: RAM SIMULATION
    # ---------------------------------------------------------
    state_ram = RamDemoState()
    state_ram.status_header = "[bold white]PHASE 2: Standard Compiler Behavior (No Bounds Checking)[/]"
    state_ram.terminal_output = "[dim]Starting execution...[/]"
    
    with Live(state_ram.render(), refresh_per_second=30, screen=True) as live:
        state_ram.log("[*] Initializing Standard Environment...")
        live.update(state_ram.render())
        wait_for_enter(live, state_ram, ">>> Press ENTER to allocate memory...")
        
        state_ram.code_line = 6
        state_ram.log("[*] Executing: allocate(A(5))")
        state_ram.terminal_output += "\nAllocating Array A(1:5)..."
        for i in range(5):
            state_ram.values[i] = "0.0"
            live.update(state_ram.render())
            time.sleep(0.1)

        wait_for_enter(live, state_ram, ">>> Press ENTER to perform valid access...")
        
        state_ram.code_line = 9
        state_ram.log("[*] Accessing Index 3 (Valid)")
        state_ram.terminal_output += "\nWriting 99.9 to A(3)..."
        for i in range(3):
            state_ram.ptr_pos = i
            live.update(state_ram.render())
            time.sleep(0.3)
            
        state_ram.values[2] = "99.9"
        state_ram.log("[+] Write successful. No memory violations.")
        live.update(state_ram.render())
    
        wait_for_enter(live, state_ram, ">>> Press ENTER to perform OUT OF BOUNDS access...")

        state_ram.code_line = 12
        state_ram.log("[!] Accessing Index 6 (Out of Bounds!)")
        state_ram.terminal_output += "\nWriting 66.6 to A(6)..."
        for i in range(2, 6):
            state_ram.ptr_pos = i
            live.update(state_ram.render())
            time.sleep(0.3)

        state_ram.is_corrupted = True
        state_ram.values[5] = "66.6"
        state_ram.status_header = "[bold white on red]SCENARIO 1: SILENT MEMORY CORRUPTION OCCURRED![/]"
        state_ram.terminal_output += "\n[bold red]WARNING: Silent corruption! Neighboring memory overwritten![/]"
        state_ram.log("[ERROR] Index 6 is outside allocated bounds!")
        state_ram.log("[ERROR] Standard compiler failed to detect violation.")
        
        for _ in range(6):
            state_ram.is_flashing = not state_ram.is_flashing
            live.update(state_ram.render())
            time.sleep(0.15)
        state_ram.is_flashing = False
        live.update(state_ram.render())

        wait_for_enter(live, state_ram, ">>> Press ENTER to reset and activate HLFIR Bounds Sanitizer...")

    # Scenario 2
    state_ram = RamDemoState()
    state_ram.status_header = "[bold white]PHASE 2 (Protected): Flang HLFIR-Aware Bounds Sanitizer[/]"
    state_ram.terminal_output = "[dim]Starting sanitized execution...[/]"
    
    with Live(state_ram.render(), refresh_per_second=30, screen=True) as live:
        state_ram.log("[*] Injecting MLIR FunctionPass...")
        time.sleep(0.5)
        state_ram.shield_active = True
        state_ram.log("[+] Bounds Sanitizer Shield ACTIVATED.")
        live.update(state_ram.render())
        wait_for_enter(live, state_ram, ">>> Press ENTER to allocate memory...")

        state_ram.code_line = 6
        state_ram.log("[*] Executing: allocate(A(5))")
        state_ram.terminal_output += "\nAllocating Array A(1:5)..."
        for i in range(5):
            state_ram.values[i] = "0.0"
            live.update(state_ram.render())
            time.sleep(0.1)

        wait_for_enter(live, state_ram, ">>> Press ENTER to perform valid access...")

        state_ram.code_line = 9
        state_ram.log("[*] Validating Index 3 against bounds [1:5]...")
        state_ram.terminal_output += "\nChecking access A(3)... OK."
        for i in range(3):
            state_ram.ptr_pos = i
            live.update(state_ram.render())
            time.sleep(0.3)
            
        state_ram.values[2] = "99.9"
        state_ram.log("[+] MLIR Guard Passed. Write successful.")
        live.update(state_ram.render())

        wait_for_enter(live, state_ram, ">>> Press ENTER to perform OUT OF BOUNDS access...")

        state_ram.code_line = 12
        state_ram.log("[!] Validating Index 6 against bounds [1:5]...")
        state_ram.terminal_output += "\nChecking access A(6)..."
        for i in range(2, 6):
            state_ram.ptr_pos = i
            live.update(state_ram.render())
            time.sleep(0.3)

        state_ram.is_flashing = True
        state_ram.status_header = "[bold white on orange1]SCENARIO 2: MLIR BOUNDS GUARD INTERCEPTED VIOLATION![/]"
        state_ram.log("[SHIELD] Access blocked at boundary!")
        state_ram.log("[SHIELD] Executing Fortran::runtime::Terminator")
        
        error_box = """
[bold red]========================================================================[/]
[bold red]                      HLFIR BOUNDS VIOLATION DETECTED                   [/]
[bold red]========================================================================[/]

  [bold white]File:[/]      [cyan]src/demo/demo.f90[/]
  [bold white]Line:[/]      [yellow]12[/]
  [bold white]Variable:[/]  [cyan]A[/]
  [bold white]Dimension:[/] [magenta]1[/]
  [bold white]Access:[/]    [bold red]6[/] (Valid Range: [[bold green]1[/]:[bold green]5[/]])

[bold red]========================================================================[/]
[dim]Program aborted by Flang Terminator gracefully.[/]
"""
        state_ram.terminal_output += "\n" + error_box
        
        for _ in range(6):
            state_ram.is_flashing = not state_ram.is_flashing
            live.update(state_ram.render())
            time.sleep(0.15)
            
        state_ram.is_flashing = False
        live.update(state_ram.render())

        wait_for_enter(live, state_ram, ">>> Press ENTER to conclude presentation...")

    console.clear()
    console.print("\n[bold green]Demonstration Concluded Successfully. Thank you.[/]\n", justify="center")
    console.print("[dim white](The presentation will remain open. Press Ctrl+C to exit.)[/]\n", justify="center")
    
    # Keep the terminal open indefinitely until the user manually exits
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    try:
        run_unified_presentation()
    except KeyboardInterrupt:
        sys.stdout.write("\033[0m\n")
        sys.exit(0)
