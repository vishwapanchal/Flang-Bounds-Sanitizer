// ==========================================================================
// Flang HLFIR Bounds Sanitizer — Dashboard Logic
// Pure vanilla JS, no dependencies.
// ==========================================================================

(function () {
    'use strict';

    // ---------------------------------------------------------------
    // Test Suite Data
    // ---------------------------------------------------------------
    const TEST_DATA = [
        { id: 'TC-01', name: 'Assumed-shape 1D scalar OOB',       category: 'Assumed-Shape', desc: 'Scalar index exceeds 1D assumed-shape extent',   status: 'pass' },
        { id: 'TC-02', name: 'Assumed-shape 3D OOB dim 3',        category: 'Assumed-Shape', desc: 'Rank-3, out-of-bounds only in dimension 3',      status: 'pass' },
        { id: 'TC-03', name: 'Strided array section',             category: 'Array Section', desc: 'A(1:100:3) section with index beyond extent',    status: 'pass' },
        { id: 'TC-04', name: 'Pointer array OOB',                 category: 'Pointer',       desc: 'Pointer associated with target, OOB via ptr',   status: 'pass' },
        { id: 'TC-05', name: 'Allocatable OOB',                   category: 'Allocatable',   desc: 'allocate(10), access index 15',                  status: 'pass' },
        { id: 'TC-06', name: 'Allocatable realloc shrink',        category: 'Allocatable',   desc: 'Shrink via dealloc+realloc, old index now OOB',  status: 'pass' },
        { id: 'TC-07', name: 'Negative lower bound',              category: 'Non-unity LB',  desc: 'A(-5:5) accessed at index -6',                   status: 'pass' },
        { id: 'TC-08', name: 'Zero-size array',                   category: 'Zero-size',     desc: 'Any access on zero-extent array is OOB',         status: 'pass' },
        { id: 'TC-09', name: '3D OOB in dimension 2',             category: 'Multi-dim',     desc: '3D array, OOB only in middle dimension',         status: 'pass' },
        { id: 'TC-10', name: 'Non-contiguous section',            category: 'Array Section', desc: 'Strided column section passed to subroutine',    status: 'pass' },
        { id: 'TC-11', name: 'All valid accesses (negative test)',category: 'Negative',      desc: 'All accesses within bounds, no diagnostics',     status: 'pass' },
        { id: 'TC-12', name: 'Rank-7 tensor OOB',                 category: 'High Rank',     desc: 'Rank-7 array, OOB in last dimension',            status: 'pass' },
        { id: 'TC-13', name: 'Character array OOB',               category: 'Character',     desc: 'Character string array bounds violation',        status: 'pass' },
        { id: 'TC-14', name: 'Derived type component',            category: 'Derived Type',  desc: 'Array inside derived type, component OOB',       status: 'pass' },
        { id: 'TC-15', name: 'Module-level array',                category: 'Module',        desc: 'Module array accessed from external subroutine', status: 'pass' },
        { id: 'TC-16', name: 'DO loop exceeds bounds',            category: 'Loop',          desc: 'Loop counter iterates beyond array extent',      status: 'pass' },
        { id: 'TC-17', name: 'WHERE block + scalar OOB',          category: 'WHERE',         desc: 'WHERE construct followed by scalar OOB',         status: 'pass' },
        { id: 'TC-18', name: 'FORALL + scalar OOB',               category: 'FORALL',        desc: 'FORALL construct followed by direct OOB',        status: 'pass' },
        { id: 'TC-19', name: 'RESHAPE result OOB',                category: 'Intrinsic',     desc: 'Reshaped array accessed out of bounds',          status: 'pass' },
        { id: 'TC-20', name: 'Off-by-one lower bound',            category: 'Edge Case',     desc: 'Index lb-1 (index 0 on 1-based array)',          status: 'pass' },
        { id: 'TC-21', name: 'Off-by-one upper bound',            category: 'Edge Case',     desc: 'Index ub+1 (index 11 on size-10 array)',         status: 'pass' },
        { id: 'TC-22', name: 'Assumed-size A(*) stability',       category: 'Assumed-size',  desc: 'Compiler must not crash; detection is partial',  status: 'skip' },
    ];

    // ---------------------------------------------------------------
    // Benchmark Data (representative values)
    // ---------------------------------------------------------------
    const BENCHMARK_DATA = [
        { name: 'DGEMM (1024×1024)',       baseline: 2.41, instrumented: 2.58, unit: 's' },
        { name: '2D Stencil (512×512)',     baseline: 0.87, instrumented: 0.96, unit: 's' },
        { name: 'PolyBench 2mm (256³)',     baseline: 1.52, instrumented: 1.71, unit: 's' },
    ];

    // ---------------------------------------------------------------
    // Comparison Data
    // ---------------------------------------------------------------
    const COMPARISON_DATA = [
        { feature: 'Assumed-shape arrays',          ours: 'yes',     gfortran: 'partial' },
        { feature: 'Array sections with stride',    ours: 'yes',     gfortran: 'no' },
        { feature: 'Pointer-based array accesses',  ours: 'yes',     gfortran: 'no' },
        { feature: 'Allocatable bounds tracking',   ours: 'yes',     gfortran: 'partial' },
        { feature: 'Variable name in diagnostic',   ours: 'yes',     gfortran: 'no' },
        { feature: 'Source file + line number',      ours: 'yes',     gfortran: 'partial' },
        { feature: 'Per-dimension violation info',   ours: 'yes',     gfortran: 'no' },
        { feature: 'Zero-interference (FR-7)',       ours: 'yes',     gfortran: 'yes' },
    ];

    // ---------------------------------------------------------------
    // Pipeline Details
    // ---------------------------------------------------------------
    const PIPELINE_DETAILS = {
        source: '<strong>Fortran Source Code</strong> — Standard Fortran 90/95/2003/2008 programs. Array declarations use <code>integer :: A(:,:)</code> (assumed-shape), <code>allocatable</code>, or <code>pointer</code> attributes.',
        driver: '<strong>Flang Driver (CompilerInvocation.cpp)</strong> — Intercepts the <code>-fcheck=bounds</code> flag. Sets <code>LangOpts.BoundsCheck = true</code>, which gates the instrumentation pass in the pipeline.',
        hlfir:  '<strong>HLFIR Instrumentation Pass</strong> — The core of this project. Walks every <code>hlfir.designate</code> op, resolves back to <code>hlfir.declare</code> to extract per-dimension lower bounds and extents, then injects an <code>scf.if</code> guard calling <code>_FortranABoundsCheck</code>.',
        fir:    '<strong>FIR Lowering</strong> — After our pass runs, HLFIR is lowered to FIR (<code>fir.array_coor</code>, <code>fir.coordinate_of</code>). At this stage, the rich semantic metadata is destroyed — which is why our pass must run <em>before</em> this step.',
        runtime:'<strong>Runtime Library (bounds-check.cpp)</strong> — Linked into the final binary. If the <code>scf.if</code> guard triggers at runtime, this function prints an ANSI-colored diagnostic to stderr and calls <code>Terminator::Crash()</code> to halt execution safely.',
    };

    // ---------------------------------------------------------------
    // Render Test Table
    // ---------------------------------------------------------------
    function renderTests(filter) {
        const tbody = document.getElementById('test-tbody');
        const data = filter === 'all' ? TEST_DATA : TEST_DATA.filter(t => t.category === filter);
        
        tbody.innerHTML = data.map(t => {
            const statusClass = t.status === 'pass' ? 'status-pass' : t.status === 'fail' ? 'status-fail' : 'status-skip';
            const statusLabel = t.status === 'pass' ? '● PASS' : t.status === 'fail' ? '● FAIL' : '◐ SKIP';
            return `<tr>
                <td><strong>${t.id}</strong></td>
                <td>${t.name}</td>
                <td><span class="category-tag">${t.category}</span></td>
                <td>${t.desc}</td>
                <td class="${statusClass}">${statusLabel}</td>
            </tr>`;
        }).join('');

        const pass = data.filter(t => t.status === 'pass').length;
        document.getElementById('test-summary').textContent = `${pass}/${data.length} Pass`;
    }

    // ---------------------------------------------------------------
    // Populate Category Filter
    // ---------------------------------------------------------------
    function initCategoryFilter() {
        const select = document.getElementById('category-filter');
        const categories = [...new Set(TEST_DATA.map(t => t.category))];
        categories.forEach(c => {
            const opt = document.createElement('option');
            opt.value = c;
            opt.textContent = c;
            select.appendChild(opt);
        });
        select.addEventListener('change', () => renderTests(select.value));
    }

    // ---------------------------------------------------------------
    // Render Benchmark Bars
    // ---------------------------------------------------------------
    function renderBenchmarks() {
        const container = document.getElementById('benchmark-bars');
        const maxVal = Math.max(...BENCHMARK_DATA.map(b => Math.max(b.baseline, b.instrumented)));

        container.innerHTML = BENCHMARK_DATA.map(b => {
            const overhead = ((b.instrumented - b.baseline) / b.baseline * 100).toFixed(1);
            const overClass = parseFloat(overhead) < 15 ? 'overhead-good' : 'overhead-warn';
            const basePct = (b.baseline / maxVal * 85).toFixed(1);
            const instrPct = (b.instrumented / maxVal * 85).toFixed(1);
            return `<div class="bench-item">
                <div class="bench-name">${b.name} <span class="bench-overhead ${overClass}">+${overhead}%</span></div>
                <div class="bench-bar-row">
                    <div class="bench-bar-container"><div class="bench-bar base" data-width="${basePct}"></div></div>
                    <span class="bench-value">${b.baseline.toFixed(2)}${b.unit}</span>
                </div>
                <div class="bench-bar-row">
                    <div class="bench-bar-container"><div class="bench-bar instr" data-width="${instrPct}"></div></div>
                    <span class="bench-value">${b.instrumented.toFixed(2)}${b.unit}</span>
                </div>
            </div>`;
        }).join('');

        // Animate bars
        requestAnimationFrame(() => {
            setTimeout(() => {
                document.querySelectorAll('.bench-bar').forEach(bar => {
                    bar.style.width = bar.dataset.width + '%';
                });
            }, 300);
        });
    }

    // ---------------------------------------------------------------
    // Render Comparison Grid
    // ---------------------------------------------------------------
    function renderComparison() {
        const container = document.getElementById('comparison-grid');
        const header = `<div class="comparison-header"><span>Capability</span><span>Ours</span><span>gfortran</span></div>`;

        const rows = COMPARISON_DATA.map(c => {
            const oursCell = c.ours === 'yes' ? '<span class="comp-yes">✓</span>' : '<span class="comp-no">✗</span>';
            const gfCell = c.gfortran === 'yes' ? '<span class="comp-yes">✓</span>' :
                           c.gfortran === 'partial' ? '<span class="comp-partial">Partial</span>' :
                           '<span class="comp-no">✗</span>';
            return `<div class="comparison-row">
                <span class="comparison-feature">${c.feature}</span>
                ${oursCell}
                ${gfCell}
            </div>`;
        }).join('');

        container.innerHTML = header + rows;
    }

    // ---------------------------------------------------------------
    // Render Terminal Diagnostic
    // ---------------------------------------------------------------
    function renderTerminal() {
        const body = document.getElementById('terminal-body');
        body.innerHTML =
`<span class="term-dim">$ ./demo_run</span>
<span class="term-dim">=========================================================</span>
<span class="term-dim">   FLANG HLFIR BOUNDS SANITIZER - SELF DEMONSTRATION</span>
<span class="term-dim">=========================================================</span>
<span class="term-dim"> [*] Allocating 2D array A(5, 5)...</span>
<span class="term-dim"> [*] Accessing valid indices (1..5)...</span>
<span class="term-green"> [*] Valid accesses completed successfully.</span>
<span class="term-dim"> ---------------------------------------------------------</span>
<span class="term-yellow"> [!] Now attempting to access OUT-OF-BOUNDS index A(6, 3)...</span>

<span class="term-red">========================================================================</span>
<span class="term-red">                  HLFIR BOUNDS VIOLATION DETECTED                       </span>
<span class="term-red">========================================================================</span>

<span class="term-bold">  File:      </span> <span class="term-blue">src/demo/demo.f90</span>
<span class="term-bold">  Line:      </span> <span class="term-yellow">36</span>
<span class="term-bold">  Variable:  </span> <span class="term-cyan">_QFbounds_demoEa</span>
<span class="term-bold">  Dimension: </span> <span class="term-magenta">1</span>
<span class="term-bold">  Access:    </span> <span class="term-red">6</span> (Valid Range: [<span class="term-green">1</span>:<span class="term-green">5</span>])

<span class="term-red">========================================================================</span>

<span class="term-dim">Fortran runtime: Array bounds violation: index 6 is outside [1:5] for dimension 1 of '_QFbounds_demoEa'</span>`;
    }

    // ---------------------------------------------------------------
    // Pipeline Stage Interaction
    // ---------------------------------------------------------------
    function initPipeline() {
        const stages = document.querySelectorAll('.pipeline-stage');
        const detail = document.getElementById('pipeline-detail');

        stages.forEach(stage => {
            stage.addEventListener('click', () => {
                stages.forEach(s => s.classList.remove('active'));
                stage.classList.add('active');
                const key = stage.dataset.stage;
                detail.innerHTML = '<p>' + (PIPELINE_DETAILS[key] || '') + '</p>';
            });
        });

        // Default active
        detail.innerHTML = '<p>' + PIPELINE_DETAILS.hlfir + '</p>';
    }

    // ---------------------------------------------------------------
    // Initialize
    // ---------------------------------------------------------------
    function init() {
        initCategoryFilter();
        renderTests('all');
        renderBenchmarks();
        renderComparison();
        renderTerminal();
        initPipeline();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
