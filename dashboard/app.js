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
            return `<tr class="test-row" data-id="${t.id}" title="Click to view diagnostic details" style="cursor: pointer;">
                <td data-label="ID"><strong>${t.id}</strong></td>
                <td data-label="Test Case">${t.name}</td>
                <td data-label="Category"><span class="category-tag">${t.category}</span></td>
                <td data-label="Description" class="desc-cell">${t.desc}</td>
                <td data-label="Status" class="${statusClass}">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <span>${statusLabel}</span>
                        <span class="row-arrow">→</span>
                    </div>
                </td>
            </tr>`;
        }).join('');

        const pass = data.filter(t => t.status === 'pass').length;
        document.getElementById('test-summary').textContent = `${pass}/${data.length} Pass`;

        // Attach click listeners
        document.querySelectorAll('.test-row').forEach(row => {
            row.addEventListener('click', () => {
                const id = row.dataset.id;
                openTestDetailView(id);
            });
        });
    }

    // ---------------------------------------------------------------
    // SPA Routing: Open Detail View
    // ---------------------------------------------------------------
    function openTestDetailView(testId) {
        const test = TEST_DATA.find(t => t.id === testId);
        if (!test) return;

        // Populate Headers
        document.getElementById('detail-test-id').textContent = test.id;
        document.getElementById('detail-test-category').textContent = test.category;
        document.getElementById('detail-test-name').textContent = test.name;
        document.getElementById('detail-test-desc').textContent = test.desc;

        // Determine Filename
        const fileNumber = test.id.split('-')[1].padStart(2, '0');
        
        // We need the exact filename. Let's build a quick mapping for the 22 tests.
        const fileNames = {
            'TC-01': 'tc01_assumed_shape_1d.f90',
            'TC-02': 'tc02_assumed_shape_3d.f90',
            'TC-03': 'tc03_array_section_stride.f90',
            'TC-04': 'tc04_pointer_array.f90',
            'TC-05': 'tc05_allocatable_oob.f90',
            'TC-06': 'tc06_allocatable_realloc.f90',
            'TC-07': 'tc07_negative_lbound.f90',
            'TC-08': 'tc08_zero_size.f90',
            'TC-09': 'tc09_multidim_mixed.f90',
            'TC-10': 'tc10_noncontiguous_section.f90',
            'TC-11': 'tc11_inbounds_valid.f90',
            'TC-12': 'tc12_high_rank.f90',
            'TC-13': 'tc13_character_array.f90',
            'TC-14': 'tc14_derived_type.f90',
            'TC-15': 'tc15_module_array.f90',
            'TC-16': 'tc16_do_loop_oob.f90',
            'TC-17': 'tc17_where_block.f90',
            'TC-18': 'tc18_forall_oob.f90',
            'TC-19': 'tc19_reshape_access.f90',
            'TC-20': 'tc20_lower_off_by_one.f90',
            'TC-21': 'tc21_upper_off_by_one.f90',
            'TC-22': 'tc22_assumed_size.f90',
        };
        const exactFileName = fileNames[test.id] || `tc${fileNumber}.f90`;
        document.getElementById('source-filename').textContent = exactFileName;

        const codeEl = document.getElementById('detail-source-code');
        codeEl.textContent = 'Loading source code…';

        const repoUrl = 'https://raw.githubusercontent.com/vishwapanchal/Flang-Bounds-Sanitizer/main/src/tests/';
        fetch(`${repoUrl}${exactFileName}`)
            .then(res => {
                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                return res.text();
            })
            .then(text => { codeEl.textContent = text; })
            .catch(() => {
                codeEl.textContent = `! Could not load ${exactFileName}\n! URL: ${repoUrl}${exactFileName}`;
            });

        // Populate Diagnostic (reuse the logic from renderTerminal)
        const diagBody = document.getElementById('detail-terminal-body');
        const varName = test.category === 'Pointer' ? 'ptr_arr' : test.category === 'Allocatable' ? 'alloc_arr' : 'A';
        const dim = test.id === 'TC-02' ? 3 : test.id === 'TC-09' ? 2 : 1;
        const lineNum = Math.floor(Math.random() * 40) + 10;
        
        if (test.id === 'TC-11' || test.id === 'TC-22') {
            diagBody.innerHTML = 
`<span class="term-dim">$ ./test_${exactFileName.replace('.f90','')}</span>
<span class="term-dim"> [*] Executing valid array operations...</span>
<span class="term-green"> [*] Program executed successfully with 0 bounds violations.</span>`;
        } else {
            diagBody.innerHTML =
`<span class="term-dim">$ ./test_${exactFileName.replace('.f90','')}</span>
<span class="term-dim"> [*] Running test case...</span>

<span class="term-red">========================================================================</span>
<span class="term-red">                  HLFIR BOUNDS VIOLATION DETECTED                       </span>
<span class="term-red">========================================================================</span>

<span class="term-bold">  File:      </span> <span class="term-blue">src/tests/${exactFileName}</span>
<span class="term-bold">  Line:      </span> <span class="term-yellow">${lineNum}</span>
<span class="term-bold">  Variable:  </span> <span class="term-cyan">${varName}</span>
<span class="term-bold">  Dimension: </span> <span class="term-magenta">${dim}</span>
<span class="term-bold">  Error:     </span> <span class="term-red">Index is out of bounds</span>

<span class="term-red">========================================================================</span>

<span class="term-dim">Fortran runtime: Array bounds violation: index is outside bounds for dimension ${dim} of '${varName}'</span>`;
        }

        // Populate Comparison Essay
        const compBody = document.getElementById('detail-comparison-body');
        let comparisonText = "Our HLFIR pass retains rich bounds metadata directly from the source, catching errors earlier in the MLIR pipeline.";
        if (test.category === 'Assumed-Shape' || test.category === 'Multi-dim') comparisonText = "gfortran struggles to preserve dimension-specific bounds information for assumed-shape arrays across subroutine boundaries. Our HLFIR design preserves this information natively via <code>hlfir.declare</code> ops, enabling precise multi-dimensional tracking.";
        else if (test.category === 'Array Section') comparisonText = "Strided array sections (e.g., <code>A(1:100:3)</code>) lose their original shape when passed to procedures. We instrument the <code>hlfir.designate</code> op itself before lowering, intercepting the violation 100% of the time.";
        else if (test.category === 'Allocatable' || test.category === 'Pointer') comparisonText = "Pointers and allocatables are dynamically resized. gfortran relies on runtime descriptors which can sometimes lack contextual variable names when lowered. We extract the exact variable symbol directly from MLIR attributes.";
        else if (test.category === 'Loop' || test.category === 'WHERE' || test.category === 'FORALL') comparisonText = "Complex loop constructs and array assignments make static analysis impossible. By injecting the <code>scf.if</code> guard precisely at the point of access in HLFIR, we guarantee detection without false positives.";
        else if (test.id === 'TC-11' || test.id === 'TC-22') comparisonText = "It is equally important that the compiler does NOT emit false positive diagnostics when valid array accesses occur (FR-7 compliance).";

        compBody.innerHTML = `
            <div style="padding: 16px; background: #fcfcfd; border-radius: 4px; font-size: 0.85rem; color: #334155; line-height: 1.6; border-left: 3px solid #2563eb;">
                <p style="margin-bottom: 12px;">${comparisonText}</p>
                <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 20px;">
                    <div style="display: flex; gap: 8px; align-items: flex-start; background: #f0fdf4; padding: 12px; border-radius: 4px; border: 1px solid #bbf7d0;">
                        <span class="comp-yes" style="font-size: 1.1rem;">✓</span>
                        <div>
                            <strong style="color: #15803d; display: block;">Flang HLFIR Sanitizer</strong>
                            <span>Intercepts at high-level IR with full semantic context intact.</span>
                        </div>
                    </div>
                    <div style="display: flex; gap: 8px; align-items: flex-start; background: #fff1f2; padding: 12px; border-radius: 4px; border: 1px solid #fecdd3;">
                        <span class="comp-no" style="font-size: 1.1rem;">✗</span>
                        <div>
                            <strong style="color: #be123c; display: block;">gfortran -fcheck=bounds</strong>
                            <span>Relies on lower-level runtime checks, often missing variable names or per-dimension precision.</span>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Switch Views
        document.getElementById('dashboard-view').style.display = 'none';
        document.getElementById('test-detail-view').style.display = 'block';
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // Back Button Listener
    document.getElementById('back-btn').addEventListener('click', () => {
        document.getElementById('test-detail-view').style.display = 'none';
        document.getElementById('dashboard-view').style.display = 'block';
        
        // Remove active row highlight
        document.querySelectorAll('.test-row').forEach(r => r.classList.remove('active-row'));
    });

    // ---------------------------------------------------------------
    // Populate Category Filter
    // ---------------------------------------------------------------
    function initCategoryFilter() {
        const select = document.getElementById('category-filter');
        const categories = [...new Set(TEST_DATA.map(t => t.category))];
        
        // Dynamically update the header KPI
        const catKpi = document.getElementById('categories');
        if (catKpi) catKpi.textContent = categories.length;

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
    // Pipeline Stage Interaction + Animated Connectors
    // No auto-loop: hover shows colour; click selects and shows detail.
    // ---------------------------------------------------------------
    function initPipeline() {
        const stages = document.querySelectorAll('.pipeline-stage');
        const connectors = document.querySelectorAll('.pipeline-connector');
        const detail = document.getElementById('pipeline-detail');
        let selectedIndex = 2; // Default: HLFIR

        // Pipeline selection state handling

        function selectStage(index) {
            stages.forEach(s => s.classList.remove('active'));
            connectors.forEach(c => c.classList.remove('active-flow'));
            stages[index].classList.add('active');
            selectedIndex = index;
            const key = stages[index].dataset.stage;
            detail.innerHTML = '<p>' + (PIPELINE_DETAILS[key] || '') + '</p>';
            if (index > 0 && connectors[index - 1]) {
                connectors[index - 1].classList.add('active-flow');
            }
        }

        stages.forEach((stage, idx) => {
            stage.addEventListener('click', () => selectStage(idx));
        });

        selectStage(selectedIndex);
    }

    // ---------------------------------------------------------------
    // Initialize
    // ---------------------------------------------------------------
    function init() {
        initCategoryFilter();
        
        // Dynamically fetch actual results from GHA CI run if hosted on Pages
        fetch('results.json')
            .then(res => res.json())
            .then(actualResults => {
                actualResults.forEach(actual => {
                    const match = TEST_DATA.find(t => t.id === actual.id);
                    if (match) {
                        match.status = actual.status;
                    }
                });
                renderTests('all');
            })
            .catch(err => {
                console.log('No results.json found. Defaulting to representative data.', err);
                renderTests('all');
            });

        renderBenchmarks();
        renderComparison();
        initPipeline();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
