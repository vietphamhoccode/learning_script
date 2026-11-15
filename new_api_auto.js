// ==UserScript==
// @name         Auto KSK & SmartCA - VNPT HIS (Pro Config Version)
// @namespace    http://tampermonkey.net/
// @version      4.0
// @description  Tự động nhập liệu KSK đủ 18 tuổi, tùy chỉnh toàn bộ thông số sinh hiệu, nội dung lâm sàng, bác sĩ, thời gian delay, timeout và ký số SmartCA siêu tốc.
// @author       AutoKSK
// @match        *://*/*
// @grant        none
// ==/UserScript==

/**
 * Tự động nhập liệu KSK và Ký số SmartCA trên hệ thống VNPT HIS
 * Tích hợp bảng cấu hình trực quan:
 * - Điều chỉnh mọi thông số nhập liệu: Bác sĩ, Lý do, Tuần hoàn, Khám lâm sàng, Địa chỉ, Đối tượng, CCCD.
 * - Điều chỉnh sinh hiệu: Chiều cao, cân nặng, BMI, huyết áp, mạch, nhịp thở, nhiệt độ cho Nam/Nữ và theo độ tuổi.
 * - Điều chỉnh tốc độ, thời gian trễ (delays) và thời gian chờ (timeouts).
 * - Tùy chọn chế độ khám (Chờ khám #kham / Đang khám #sua), kiểm tra BHYT, Ký số SmartCA 2 vai trò.
 * - Lưu và khôi phục cấu hình qua localStorage.
 * - Hỗ trợ cả Tampermonkey và chạy trực tiếp trên Console trình duyệt / Bookmarklet.
 */

(function () {
    'use strict';

    if (typeof window === 'undefined') return;

    // Kiểm tra jQuery
    if (!window.jQuery) {
        console.warn('[KSK_AUTO] Trang hiện tại chưa tải jQuery. Đang đợi jQuery...');
        const jqCheck = setInterval(() => {
            if (window.jQuery) {
                clearInterval(jqCheck);
                initScript();
            }
        }, 500);
        return;
    }

    initScript();

    function initScript() {
        const $ = window.jQuery;

        // Xóa instance cũ nếu đang chạy
        if (window.KSK_AUTO && typeof window.KSK_AUTO._destroy === 'function') {
            try { window.KSK_AUTO._destroy(); } catch (e) { }
        }

        // =========================================================================
        // 1. CẤU HÌNH MẶC ĐỊNH (DEFAULT CONFIGURATION)
        // =========================================================================
        const STORAGE_KEY = 'KSK_AUTO_CONFIG_V4_1';

        const DEFAULT_CONFIG = {
            // Chế độ & Tính năng chung
            examMode: 'cho_kham',        // 'cho_kham' -> ấn #kham | 'dang_kham' -> ấn #sua
            enableKySo: true,            // Bật/tắt ký số SmartCA
            autoDisableOnLoginAlert: true, // Tự động phát hiện & tắt ký số khi có bảng Đăng nhập SmartCA
            enableAutoRefresh: true,     // Tự động bấm #lammoi khi hết danh sách
            enableCheckBhyt: true,       // Bật/tắt kiểm tra BHYT (#kt_tt_thebhyt)
            autoFixCccd: true,           // Tự động chèn 0 vào đầu CCCD 11 số
            skipInvalidCccd: true,       // Bỏ qua BN nếu CCCD không đủ 12 số
            apiMode: true,               // Gọi API HIS trực tiếp (nhanh gấp 10x, tự fallback UI nếu lỗi)

            // Bác sĩ & Nội dung KSK
            maBacSi: '1327430',
            tenBacSi: 'BSCKI. Nguyễn Thị Mỹ Chi',
            lyDoKham: 'Kiểm tra khám sàng lọc',
            noiDungTuanHoan: 'Chưa phát hiện bệnh lý',
            noiDungLamSang: 'Chưa phát hiện bệnh lý',
            noiDungMat: 'Bình thường',
            noiDungTai: 'Bình thường',
            noiDungRang: 'Bình thường',
            diaChiThem: 'P. Long Châu',
            chiSoThiLuc: '10/10',
            chiSoTaiThuong: '5m',
            chiSoTaiTham: '0.5m',

            // Phân loại đối tượng theo tuổi
            tuoiSinhVienMax: 22,         // <= 22: đối tượng 11 hoặc 12 (HSSV)
            dtHocSinhSinhVien: '11',
            dtNguoiLaoDong: '13',        // 23 - 60: đối tượng 13 (Người lao động)
            dtNguoiCaoTuoi: '1',         // > 60: đối tượng 1 (Người cao tuổi)

            // Thời gian thao tác, Delays & Timeouts (ms)
            stepDelay: 80,               // Delay ngắn giữa các lệnh thao tác form (ms)
            quietDelay: 150,             // Thời gian chờ giao diện ổn định (waitIdle)
            pollInterval: 50,            // Chu kỳ kiểm tra trạng thái / dialogs (ms)
            emptyWaitMs: 3000,           // Chờ khi hết danh sách trước khi quét lại (ms)
            bnReadyTimeout: 12000,       // Timeout chờ BN nạp đầy đủ họ tên, tuổi (ms)
            kskLoadTimeout: 12000,       // Timeout chờ mở phiếu KSK (ms)
            kysoGridWaitMs: 4000,        // Timeout tìm nút ký XML_KSK trong tab Khác (ms)
            kysoWaitMs: 30000,           // Timeout chờ xác nhận ký số SmartCA trên App (ms)

            // Sinh hiệu - Chiều cao Nam (cm)
            namHeightMin: 160,
            namHeightMax: 175,
            namHeight60Min: 155,
            namHeight60Max: 170,

            // Sinh hiệu - Chiều cao Nữ (cm)
            nuHeightMin: 150,
            nuHeightMax: 165,
            nuHeight60Min: 145,
            nuHeight60Max: 160,

            // Sinh hiệu - Cân nặng & BMI
            useBmiForWeight: true,       // Tự tính cân nặng chuẩn dựa theo BMI và chiều cao
            bmiMin: 20.0,
            bmiMax: 24.0,

            // Sinh hiệu - Mạch (lần/phút)
            machMin: 65,
            machMax: 90,
            mach60Min: 60,
            mach60Max: 85,

            // Sinh hiệu - Nhịp thở & Nhiệt độ
            nhipThoMin: 16,
            nhipThoMax: 20,
            nhietDo: 37.0,

            // Sinh hiệu - Huyết áp (mmHg)
            haMin: 100,
            haMax: 128,
            ha60Min: 120,
            ha60Max: 140,

            // Ký số SmartCA
            vaiTro1: 'CKS_NGUOI_KET_LUAN', // Vai trò 1: Người kết luận
            vaiTro2: 'CKS_BENH_VIEN'       // Vai trò 2: Chữ ký bệnh viện
        };

        // Danh sách các mục lâm sàng và ID select bác sĩ chuyên khoa
        const LS_MUC = [
            { nd: 'tt32_mau2tuanhoan', bs: 'tt32_mau2bacsituanhoan', label: 'Tuần hoàn' },
            { nd: 'tt32_mau2noitiet', bs: 'tt32_mau2bacsinoitiet', label: 'Nội tiết' },
            { nd: 'tt32_mau2hohap', bs: 'tt32_mau2bacsihohap', label: 'Hô hấp' },
            { nd: 'tt32_mau2tieuhoa', bs: 'tt32_mau2bacsitieuhoa', label: 'Tiêu hóa' },
            { nd: 'tt32_mau2tietnieu', bs: 'tt32_mau2bacsitietnieu', label: 'Tiết niệu' },
            { nd: 'tt32_mau2coxuongkhop', bs: 'tt32_mau2bacsixuongkhop', label: 'Cơ xương khớp' },
            { nd: 'tt32_mau2thankinh', bs: 'tt32_mau2bacsithankinh', label: 'Thần kinh' },
            { nd: 'tt32_mau2tamthan', bs: 'tt32_mau2bacsitamthan', label: 'Tâm thần' },
            { nd: 'tt32_mau2ngoaikhoa', bs: 'tt32_mau2bacsingoaikhoa', label: 'Ngoại khoa' },
            { nd: 'tt32_mau2ngkdalieu', bs: 'tt32_mau2bacsidalieu', altBs: 'tt32_mau2bacsingoaikhoa', label: 'Da liễu' },
            { nd: 'tt32_mau2benhvemat', bs: 'tt32_mau2bacsimat', label: 'Mắt' },
            { nd: 'tt32_mau2benhvetai', bs: 'tt32_mau2bacsitaimuihong', label: 'Tai mũi họng' },
            { nd: 'tt32_mau2benhverang', bs: 'tt32_mau2bacsiranghammat', label: 'Răng hàm mặt' }
        ];

        // Biến cấu hình hoạt động (Active Config)
        let CFG = Object.assign({}, DEFAULT_CONFIG);

        // Nạp cấu hình từ localStorage nếu có
        function loadSavedConfig() {
            try {
                const saved = localStorage.getItem(STORAGE_KEY);
                if (saved) {
                    const parsed = JSON.parse(saved);
                    CFG = Object.assign({}, DEFAULT_CONFIG, parsed);
                }
            } catch (e) {
                console.warn('[KSK_AUTO] Không thể đọc cấu hình từ localStorage:', e);
            }
        }

        function saveConfigToStorage() {
            try {
                localStorage.setItem(STORAGE_KEY, JSON.stringify(CFG));
                return true;
            } catch (e) {
                console.error('[KSK_AUTO] Lỗi khi lưu cấu hình vào localStorage:', e);
                return false;
            }
        }

        loadSavedConfig();

        // =========================================================================
        // 2. BIẾN TRẠNG THÁI HỆ THỐNG (STATE MANAGEMENT)
        // =========================================================================
        let STOP = true;
        let RUNNING = false;
        let IS_PAUSED = false;
        let CONTINUOUS = false;
        let REFRESH_REQUESTED = false;
        let STEP = 0;
        let COMPLETED_COUNT = 0;
        const LOGS = [];
        const DONE = new Set();
        const BN_DONE = new Set();
        const KYSO_DONE = {};

        // Helper toán học & tiện ích
        const sleep = (ms) => new Promise(r => setTimeout(r, ms));
        const rnd = (a, b) => Math.floor(Math.random() * (b - a + 1)) + a;
        const rndFloat = (a, b, dec = 1) => parseFloat((Math.random() * (b - a) + a).toFixed(dec));

        function stripVn(s) {
            return String(s || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
        }

        function triggerEvent(el, evName) {
            if (!el) return;
            try {
                el.dispatchEvent(new Event(evName, { bubbles: true }));
            } catch (e) { }
        }

        // =========================================================================
        // 3. HỆ THỐNG GHI LOG & CẬP NHẬT TRẠNG THÁI GIAO DIỆN
        // =========================================================================
        function pushLog(line, type = 'info') {
            LOGS.push({ line, type });
            if (LOGS.length > 200) LOGS.shift();

            const box = document.getElementById('ksk_auto_log');
            if (box) {
                const row = document.createElement('div');
                row.className = `ksk-log-line ksk-log-${type}`;
                row.textContent = line;
                box.appendChild(row);
                box.scrollTop = box.scrollHeight;
                while (box.children.length > 80) box.removeChild(box.firstChild);
            }
        }

        function log(msg) {
            STEP++;
            const t = new Date().toLocaleTimeString('vi-VN');
            const line = `#${STEP} [${t}] ${msg}`;
            console.log(`[KSK_AUTO] ${line}`);
            pushLog(line, 'info');
            setStatus(msg);
        }

        function success(msg) {
            STEP++;
            const t = new Date().toLocaleTimeString('vi-VN');
            const line = `#${STEP} [${t}] ✓ ${msg}`;
            console.log(`[KSK_AUTO] ${line}`);
            pushLog(line, 'success');
            setStatus(msg);
        }

        function warn(msg) {
            STEP++;
            const t = new Date().toLocaleTimeString('vi-VN');
            const line = `#${STEP} [${t}] ⚠ ${msg}`;
            console.warn(`[KSK_AUTO] ${line}`);
            pushLog(line, 'warn');
            setStatus(msg);
        }

        function setStatus(s) {
            const el = document.getElementById('ksk_auto_status');
            if (el) el.textContent = s;
        }

        function updateCount() {
            const elList = document.getElementById('ksk_stat_total');
            const elDone = document.getElementById('ksk_stat_done');
            const elPending = document.getElementById('ksk_stat_pending');
            const allIds = rowIds();
            const pIds = pendingIds();

            if (elList) elList.textContent = allIds.length;
            if (elDone) elDone.textContent = COMPLETED_COUNT;
            if (elPending) elPending.textContent = pIds.length;
        }

        // =========================================================================
        // 4. TIỆN ÍCH DỮ LIỆU & LƯỚI BỆNH NHÂN (HIS GRID & DOM HELPERS)
        // =========================================================================
        function bnMayte() {
            return ($('#mayte').val() || '').trim();
        }

        function mayteOfRow(id) {
            try {
                const r = $('#list1').jqGrid('getRowData', id);
                return r && r.MA_BENH_NHAN ? String(r.MA_BENH_NHAN).replace(/<[^>]*>?/gm, '').trim() : '';
            } catch (e) {
                return '';
            }
        }

        function rowIds() {
            try {
                return $('#list1').jqGrid('getDataIDs') || [];
            } catch (e) {
                return [];
            }
        }

        function pendingIds() {
            return rowIds().filter(function (id) {
                if (DONE.has(String(id))) return false;
                const m = mayteOfRow(id);
                if (m && BN_DONE.has(m)) {
                    DONE.add(String(id));
                    return false;
                }
                return true;
            });
        }

        function pickRandomId() {
            const ids = pendingIds();
            if (!ids.length) return null;
            const id = ids[rnd(0, ids.length - 1)];
            const ret = $('#list1').jqGrid('getRowData', id);
            const ten = (ret && (ret.TEN_BENH_NHAN || ret.TEN_BENH_NHAN_HT || '')).replace(/<[^>]*>?/gm, '').trim() || '?';
            log(`🎲 Chọn ngẫu nhiên hàng ${id} (${ids.length} ca chờ): ${ten}`);
            updateCount();
            return id;
        }

        function markBnDone(id) {
            DONE.add(String(id));
            const m = bnMayte() || mayteOfRow(id);
            if (m) BN_DONE.add(m);
            COMPLETED_COUNT++;
            updateCount();
        }

        function setVal(id, v) {
            const $el = $('#' + id);
            if (!$el.length) return;
            $el.val(v);
            triggerEvent($el[0], 'input');
            triggerEvent($el[0], 'change');
            $el.trigger('change').trigger('input');
        }

        function setChosen(id, v) {
            const $el = $('#' + id);
            if (!$el.length) return false;
            const el = $el[0];

            if ($el.find('option[value="' + v + '"]').length) {
                $el.val(v);
            } else {
                let hit = false;
                $el.find('option').each(function () {
                    if (String(this.value) === String(v) || String(this.value).indexOf(v) >= 0) {
                        this.selected = true;
                        hit = true;
                        return false;
                    }
                });
                if (!hit && CFG.tenBacSi) {
                    const searchName = stripVn(CFG.tenBacSi);
                    $el.find('option').each(function () {
                        if (stripVn(this.textContent || '').indexOf(searchName) >= 0) {
                            this.selected = true;
                            hit = true;
                            return false;
                        }
                    });
                }
                if (!hit) {
                    const firstValid = $el.find('option').filter(function () {
                        return this.value && this.value !== '0';
                    }).first();
                    if (firstValid.length) {
                        firstValid.prop('selected', true);
                        hit = true;
                    }
                }
                if (!hit) {
                    warn(`Không tìm thấy option BS=${v} trong #${id}`);
                    return false;
                }
            }

            triggerEvent(el, 'change');
            $el.trigger('chosen:updated').trigger('change');
            return true;
        }

        function closeChosenDrops() {
            try {
                $('.chosen-container').removeClass('chosen-with-drop chosen-container-active');
                $('.chosen-drop').hide();
            } catch (e) { }
        }

        function isLoadingUi() {
            if ($('.blockUI').filter(':visible').length) return true;
            if ($('#load_list1').is(':visible')) return true;
            let busy = false;
            $('.loading').each(function () {
                if ($(this).is(':visible') && $(this).css('display') !== 'none') busy = true;
            });
            return busy;
        }

        async function waitIdle(maxMs = 8000, quietMs = null, label = '') {
            quietMs = quietMs == null ? CFG.quietDelay : quietMs;
            if (isLoadingUi()) log(`Đang chờ nạp dữ liệu... ${label}`);
            const t0 = Date.now();
            let quietFrom = null;

            while (Date.now() - t0 < maxMs) {
                if (STOP && label !== 'force') return false;
                if (isLoadingUi()) {
                    quietFrom = null;
                } else {
                    if (quietFrom == null) quietFrom = Date.now();
                    if (Date.now() - quietFrom >= quietMs) return true;
                }
                await sleep(CFG.pollInterval);
            }
            return true;
        }

        async function guardReady(label) {
            if (!isLoadingUi()) return true;
            log(`Chờ tải xong: ${label}`);
            await waitIdle(6000, CFG.quietDelay, label);
            return true;
        }

        function isConfirmBtnText(t) {
            t = String(t || '').trim();
            return /^(OK|Đồng ý|Có|Tiếp tục|Xác nhận|Confirm|Yes|Xong)$/i.test(t) || /^xác\s*nhận$/i.test(t);
        }

        async function clickDongY(maxMs = 2500) {
            const t0 = Date.now();
            let n = 0;
            while (Date.now() - t0 < maxMs) {
                let hit = false;
                $('.ui-dialog-buttonset button, button.ui-button, #popup_ok, .jAlert button, .smartca-ad-alert button, .swal2-confirm, button.confirm').each(function () {
                    if (!$(this).is(':visible')) return;
                    const t = ($(this).text() || $(this).val() || '').trim();
                    if (isConfirmBtnText(t)) {
                        $(this).trigger('click');
                        hit = true;
                        n++;
                    }
                });

                if ($('#popup_ok').is(':visible')) {
                    $('#popup_ok').trigger('click');
                    hit = true;
                    n++;
                }

                if (!hit) break;
                await sleep(CFG.pollInterval);
            }
            if (n) log(`Đã bấm Xác nhận/Đồng ý ×${n}`);
            return n;
        }

        function dangNhapLieu() {
            const hasBn = !!($('#hoten').val() || '').trim();
            if (!hasBn) return false;
            const ttk = $('input[name=trangthaikham]:checked').val();
            if (ttk === '2') return true;
            if (typeof trangthaikham !== 'undefined' && (trangthaikham === 'kham' || trangthaikham === 'sua')) return true;
            if ($('#kham').prop('disabled')) return true;
            return false;
        }

        async function waitBnReady(ms = 12000) {
            log('Chờ tải thông tin bệnh nhân...');
            const t0 = Date.now();
            while (Date.now() - t0 < (ms || CFG.bnReadyTimeout)) {
                if (STOP) return false;
                const hoten = ($('#hoten').val() || '').trim();
                const tuoi = ($('#tuoi').val() || '').trim();
                const mayte = ($('#mayte').val() || '').trim();

                if (hoten && tuoi !== '' && mayte && !isLoadingUi()) {
                    await sleep(CFG.quietDelay);
                    if (($('#hoten').val() || '').trim() === hoten && ($('#tuoi').val() || '').trim() === tuoi) {
                        log(`✓ Bệnh nhân sẵn sàng: ${hoten} (${tuoi} tuổi, Mã: ${mayte})`);
                        return true;
                    }
                }
                await sleep(CFG.pollInterval);
            }
            warn('Thông tin bệnh nhân chưa nạp xong');
            return false;
        }

        function findEditButton() {
            const selectors = ['#sua', '#suakham', '#btnSua'];
            for (const sel of selectors) {
                const $el = $(sel);
                if ($el.length && $el.is(':visible')) return $el;
            }
            return $('button, input[type="button"]').filter(function () {
                if (!$(this).is(':visible')) return false;
                const label = (this.tagName === 'INPUT' ? $(this).val() : $(this).text() || '').trim().toLowerCase();
                return label === 'sửa' || label === 'sua';
            }).first();
        }

        async function ensureExamOpen() {
            if (dangNhapLieu()) {
                log('Hệ thống đang ở trạng thái nhập liệu.');
                return await waitBnReady(CFG.bnReadyTimeout);
            }

            const isDangKhamMode = CFG.examMode === 'dang_kham';
            if (isDangKhamMode) {
                const $btnSua = findEditButton();
                if (!$btnSua.length || $btnSua.prop('disabled')) {
                    warn('Nút "Sửa" không khả dụng hoặc bị disabled.');
                    return false;
                }
                log('→ Ấn nút "Sửa" (#sua - Chế độ Đang khám)');
                $btnSua.click();
            } else {
                const $btnKham = $('#kham');
                if (!$btnKham.length || $btnKham.prop('disabled')) {
                    warn('Nút "Khám" (#kham) bị disabled hoặc không tìm thấy.');
                    return false;
                }
                log('→ Ấn nút "Khám" (#kham - Chế độ Chờ khám)');
                $btnKham.click();
            }

            await sleep(CFG.stepDelay);
            await clickDongY(600);
            return await waitBnReady(CFG.bnReadyTimeout);
        }

        async function luuDanhSachBn() {
            log('→ Lưu danh sách bệnh nhân (#luu)');
            await guardReady('Lưu DS');
            const $luu = $('#luu');
            if (!$luu.length) {
                warn('Không tìm thấy nút #luu');
                return false;
            }
            if ($luu.prop('disabled') || $luu.hasClass('button_disabled')) {
                warn('Nút #luu đang bị disabled, bỏ qua bước lưu');
                return false;
            }
            try { $luu[0].click(); } catch (e) { $luu.click(); }
            await clickDongY(2000);
            await waitIdle(5000, CFG.quietDelay);
            await clickDongY(600);
            log('✓ Đã lưu danh sách BN');
            return true;
        }

        async function safeHuy() {
            await waitIdle(3000, CFG.quietDelay);
            if (!dangNhapLieu() && !($('#hoten').val() || '').trim()) return;
            try {
                await luuDanhSachBn();
            } catch (e) {
                warn(`Lỗi lưu trước khi hủy: ${e && e.message}`);
            }
            log('→ Ấn nút "Hủy" (#huy) để đóng ca khám');
            $('#huy').click();
            await clickDongY(1000);
            await waitIdle(3000, CFG.quietDelay);
        }

        async function refreshList() {
            log('⟳ Đang làm mới danh sách bệnh nhân (#lammoi)...');
            try {
                $('#lammoi').click();
            } catch (e) {
                warn(`Lỗi khi click #lammoi: ${e && e.message}`);
            }
            await sleep(300);
            await waitIdle(6000, CFG.quietDelay, 'reload list');

            const now = {};
            rowIds().forEach(id => { now[String(id)] = true; });
            Array.from(DONE).forEach(id => {
                if (!now[id]) DONE.delete(id);
            });
            updateCount();
            log(`✓ Danh sách sau khi làm mới: ${rowIds().length} BN | Còn xử lý: ${pendingIds().length} BN`);
        }

        // =========================================================================
        // 5. TÍNH TOÁN SINH HIỆU & ĐIỀN THÔNG SỐ (VITALS CALCULATION)
        // =========================================================================
        function haDuoiTheoTren(tren) {
            if (tren <= 100) return 60;
            if (tren < 110) return 70;
            if (tren >= 120) return 80;
            return 70;
        }

        function generateVitals(age, isNam) {
            const isCaoTuoi = age >= 60;

            // Chiều cao theo giới tính và tuổi
            let h;
            if (isNam) {
                h = rnd(isCaoTuoi ? CFG.namHeight60Min : CFG.namHeightMin, isCaoTuoi ? CFG.namHeight60Max : CFG.namHeightMax);
            } else {
                h = rnd(isCaoTuoi ? CFG.nuHeight60Min : CFG.nuHeightMin, isCaoTuoi ? CFG.nuHeight60Max : CFG.nuHeightMax);
            }

            // Cân nặng tính theo BMI hoặc trực tiếp
            const bmi = rndFloat(CFG.bmiMin, CFG.bmiMax, 1);
            let w;
            if (CFG.useBmiForWeight) {
                w = Math.round((bmi * h * h) / 10000);
            } else {
                w = isNam ? rnd(52, 75) : rnd(43, 60);
            }

            // Huyết áp
            const tren = isCaoTuoi ? rnd(CFG.ha60Min, CFG.ha60Max) : rnd(CFG.haMin, CFG.haMax);
            const duoi = haDuoiTheoTren(tren);

            // Mạch & nhịp thở
            const mach = isCaoTuoi ? rnd(CFG.mach60Min, CFG.mach60Max) : rnd(CFG.machMin, CFG.machMax);
            const nhiptho = rnd(CFG.nhipThoMin, CFG.nhipThoMax);
            const nhietdo = CFG.nhietDo;

            return {
                mach,
                nhiptho,
                chieucao: h,
                cannang: w,
                bmi,
                nhietdo,
                huyetaptren: tren,
                huyetapduoi: duoi
            };
        }

        function fillSinhHieu(v) {
            log(`Điền sinh hiệu: Mạch ${v.mach}, Thở ${v.nhiptho}, Cao ${v.chieucao}cm, Nặng ${v.cannang}kg, HA ${v.huyetaptren}/${v.huyetapduoi}`);
            setVal('mach', v.mach);
            setVal('nhiptho', v.nhiptho);
            setVal('chieucao', v.chieucao);
            setVal('cannang', v.cannang);
            setVal('nhietdo', v.nhietdo);
            setVal('huyetaptren', v.huyetaptren);
            setVal('huyetapduoi', v.huyetapduoi);
            if ($('#chisobmi').length) setVal('chisobmi', v.bmi);
        }

        function doiTuongTheoTuoi(age) {
            if (age > 60) return CFG.dtNguoiCaoTuoi || '1';
            if (age <= CFG.tuoiSinhVienMax) return CFG.dtHocSinhSinhVien || '11';
            return CFG.dtNguoiLaoDong || '13';
        }

        function fixCmnd(raw) {
            const s = String(raw || '').replace(/\s+/g, '').trim();
            if (/^\d{12}$/.test(s)) return s;
            if (/^\d{11}$/.test(s) && CFG.autoFixCccd) return '0' + s;
            return null;
        }

        function applyCmndOrFail() {
            let $el = $('#tt32_mau2ksksocmnd');
            if (!$el.length) $el = $('#socmnd');
            const raw = ($el.val() || '').trim();
            const fixed = fixCmnd(raw);

            if (!fixed) {
                if (CFG.skipInvalidCccd) {
                    warn(`CCCD/CMND không hợp lệ ("${raw}", độ dài: ${raw.length}) → Bỏ qua ca khám.`);
                    return false;
                }
                return true;
            }

            if (fixed !== raw) {
                log(`Tự động bổ sung 0 vào đầu CCCD: ${raw} → ${fixed}`);
                $el.val(fixed).trigger('change');
            } else {
                log(`CCCD chuẩn 12 số: ${fixed}`);
            }
            return true;
        }

        function isAddressComplete(cur, diaChiThem) {
            if (!cur) return false;
            const cleanCur = stripVn(cur);
            const cleanThem = stripVn(diaChiThem);
            if (cleanThem && cleanCur.indexOf(cleanThem) >= 0) return true;
            if (/long\s*chau/.test(cleanCur) && /long\s*chau/.test(cleanThem)) return true;
            return false;
        }

        function patchDiaChi() {
            const $d = $('#tt32_mau2kskdiachi');
            if (!$d.length) return;
            const cur = ($d.val() || '').trim();
            const diaChiThem = CFG.diaChiThem || 'P. Long Châu';

            if (isAddressComplete(cur, diaChiThem)) return;

            const newVal = cur ? `${cur}, ${diaChiThem}` : diaChiThem;
            $d.val(newVal).trigger('change');
            log(`Bổ sung địa chỉ: ${newVal}`);
        }

        // =========================================================================
        // 6. KIỂM TRA BHYT & ĐIỀN PHIẾU KHÁM SỨC KHỎE ĐỦ 18 TUỔI
        // =========================================================================
        async function openBhyt() {
            if (!CFG.enableCheckBhyt) return;
            log('→ Kiểm tra thẻ BHYT (#kt_tt_thebhyt)');
            await guardReady('BHYT');

            const id = $('#list1').jqGrid('getGridParam', 'selrow');
            const ret = id ? $('#list1').jqGrid('getRowData', id) : null;
            if (ret && String(ret.CO_BAO_HIEM) === '0') {
                log('BN không có BHYT, bỏ qua kiểm tra thẻ');
                return;
            }

            try {
                const btn = $('#kt_tt_thebhyt');
                if (btn.length && !btn.prop('disabled')) btn[0].click();
            } catch (e) {
                warn(`Lỗi khi click BHYT: ${e && e.message}`);
                return;
            }

            const t0 = Date.now();
            while (Date.now() - t0 < 1800) {
                await clickDongY(150);
                try {
                    if ($('#formKiemtrattbhyt_modal').hasClass('ui-dialog-content') && $('#formKiemtrattbhyt_modal').dialog('isOpen')) break;
                } catch (e) { }
                await sleep(CFG.pollInterval);
            }

            try {
                if ($('#formKiemtrattbhyt_modal').hasClass('ui-dialog-content') && $('#formKiemtrattbhyt_modal').dialog('isOpen')) {
                    $('#formKiemtrattbhyt_modal').dialog('close');
                }
            } catch (e) { }
            await waitIdle(3000, CFG.quietDelay);
        }

        function fillLamSangAll(isNu = false) {
            log(`Điền lâm sàng các chuyên khoa (BS: ${CFG.maBacSi})`);
            const bs = CFG.maBacSi;
            const noiDungChung = CFG.noiDungLamSang || 'Chưa phát hiện bệnh lý';
            const noiDungTuanHoan = CFG.noiDungTuanHoan || 'Chưa phát hiện bệnh lý';

            for (let i = 0; i < LS_MUC.length; i++) {
                const m = LS_MUC[i];
                const content = m.nd === 'tt32_mau2tuanhoan' ? noiDungTuanHoan :
                    (m.nd === 'tt32_mau2benhvemat' ? (CFG.noiDungMat || 'Bình thường') :
                        (m.nd === 'tt32_mau2benhvetai' ? (CFG.noiDungTai || 'Bình thường') :
                            (m.nd === 'tt32_mau2benhverang' ? (CFG.noiDungRang || 'Bình thường') : noiDungChung)));

                setVal(m.nd, content);
                if (m.bs) {
                    const ok = setChosen(m.bs, bs);
                    if (!ok && m.altBs) setChosen(m.altBs, bs);
                }
            }

            // Chuyên khoa lẻ & Mắt, Tai mũi họng, Răng hàm mặt
            setVal('tt32_mau2khongkinhmatphai', CFG.chiSoThiLuc || '10/10');
            setVal('tt32_mau2khongkinhmattrai', CFG.chiSoThiLuc || '10/10');
            setVal('tt32_mau2taitrainoithuong', CFG.chiSoTaiThuong || '5m');
            setVal('tt32_mau2taitrainoitham', CFG.chiSoTaiTham || '0.5m');
            setVal('tt32_mau2taiphainoithuong', CFG.chiSoTaiThuong || '5m');
            setVal('tt32_mau2taiphainoitham', CFG.chiSoTaiTham || '0.5m');
            setVal('tt32_mau2ranghamtren', 'Bình thường');
            setVal('tt32_mau2ranghamduoi', 'Bình thường');

            // Sản phụ khoa nếu là Nữ
            if (isNu) {
                setVal('tt32_mau2sanphukhoa', noiDungChung);
                setChosen('tt32_mau2bacsiphukhoa', bs);
            } else {
                setVal('tt32_mau2sanphukhoa', '');
                setChosen('tt32_mau2bacsiphukhoa', '0');
            }

            try {
                $('#tt32_mau2ksk-tab3 select').trigger('chosen:updated');
                if (typeof window.tt32_ksk_updateAllBadges_mau2 === 'function') {
                    window.tt32_ksk_updateAllBadges_mau2();
                }
            } catch (e) { }

            closeChosenDrops();
        }

        function lamSangMissing() {
            const miss = [];
            for (let i = 0; i < LS_MUC.length; i++) {
                const m = LS_MUC[i];
                const nd = ($('#' + m.nd).val() || '').trim();
                if (!nd) miss.push(m.label || m.nd);

                if (m.bs) {
                    const bv = String($('#' + m.bs).val() || '');
                    if (!bv || bv === '0') miss.push(`BS ${m.label || m.bs}`);
                }
            }
            return miss;
        }

        async function fillLamSangVerified(isNu = false) {
            const t0 = Date.now();
            while (Date.now() - t0 < 4000) {
                if ($('#tt32_mau2tuanhoan').length) break;
                await sleep(100);
            }

            if (!$('#tt32_mau2tuanhoan').length) {
                warn('Không tìm thấy tab lâm sàng (#tt32_mau2tuanhoan)');
                return false;
            }

            for (let attempt = 1; attempt <= 4; attempt++) {
                fillLamSangAll(isNu);
                await sleep(180);
                const miss = lamSangMissing();
                if (!miss.length) {
                    closeChosenDrops();
                    log('✓ Đã điền đầy đủ tất cả chuyên khoa lâm sàng và bác sĩ');
                    return true;
                }
                warn(`Lâm sàng còn thiếu lần ${attempt}: ${miss.slice(0, 5).join(', ')}${miss.length > 5 ? '…' : ''}`);
                await sleep(250);
                await waitIdle(2000, 150);
            }
            return false;
        }

        function closeKskDialog() {
            try {
                if (typeof tt32_khamsuckhoetheodtmaudu18_dialog !== 'undefined') {
                    tt32_khamsuckhoetheodtmaudu18_dialog.dialog('close');
                } else {
                    $('#tt32_mau2_khamkstheomau_div').dialog('close');
                }
            } catch (e) { }
            autoDismissPopups();
        }

        function autoDismissPopups() {
            const popups = ['#popup_ok', '.smartca-alert-button-confirm', '.swal2-confirm'];
            for (const sel of popups) {
                const el = document.querySelector(sel);
                if (el && el.offsetParent !== null) {
                    el.click();
                    return true;
                }
            }
            return false;
        }

        async function waitKskLoad(ms = 12000) {
            log('Chờ phiếu KSK nạp xong thông tin...');
            const t0 = Date.now();
            let sawHoten = false;

            while (Date.now() - t0 < ms) {
                if (STOP) return false;
                if (($('#tt32_mau2kskhoten').val() || '').trim()) {
                    if (!sawHoten) {
                        sawHoten = true;
                        log('Đã có họ tên phiếu KSK — chờ AJAX load dữ liệu...');
                    }
                    await waitIdle(4000, Math.max(CFG.quietDelay, 250));
                    await sleep(200);
                    if ($('#tt32_mau2tuanhoan').length && $('#tt32_mau2bacsituanhoan').length) {
                        log('✓ Phiếu KSK đã sẵn sàng nhập liệu');
                        return true;
                    }
                }
                await sleep(CFG.pollInterval);
            }
            return sawHoten;
        }

        function getBsOptionText(selectId, bsVal) {
            const $opt = $('#' + selectId + ' option[value="' + bsVal + '"]');
            if ($opt.length) return $opt.text().trim();
            return CFG.tenBacSi || '';
        }

        function getNguonChiTra(dt) {
            const map = {
                '1': '2', '2': '2', '3': '2', '4': '2', '5': '2', '14': '2',
                '6': '1', '7': '1', '8': '1', '9': '1',
                '10': '9', '11': '9', '12': '9', '15': '9', '16': '9',
                '13': '4'
            };
            return map[String(dt)] || '9';
        }

        async function fillKskViaApi(age, v, isNu = false) {
            const dvttVal = typeof window.dvtt !== 'undefined' ? window.dvtt : (typeof window.Sess_DVTT !== 'undefined' ? window.Sess_DVTT : '');
            const mabenhnhan = ($('#mayte').val() || '').trim();
            const sovaovien = ($('#sovaovien').val() || '').trim();

            if (!dvttVal || !mabenhnhan || !sovaovien) {
                warn('API Mode: Thiếu dvtt / mayte / sovaovien — Chuyển sang chế độ UI');
                return null;
            }

            try {
                log('⚡ [API Mode] Bước 1/4: Kiểm tra tồn tại & tải thông tin gốc BN...');
                const sttRaw = await $.ajax({
                    url: `ksktheodoituongkiemtratontai-tt32?dvtt=${encodeURIComponent(dvttVal)}&mabenhnhan=${encodeURIComponent(mabenhnhan)}&sovaovien=${encodeURIComponent(sovaovien)}`,
                    type: 'GET'
                });
                const stt = String(sttRaw || '0').trim();

                const infoUrl = `getthongtinbenhnhankhamsktheodoituong-tt32?dvtt=${encodeURIComponent(dvttVal)}&mabenhnhan=${encodeURIComponent(mabenhnhan)}&sovaovien=${encodeURIComponent(sovaovien)}`;

                const [field, soLuuTruRaw] = await Promise.all([
                    $.ajax({ url: infoUrl, type: 'GET', dataType: 'json' }),
                    $.ajax({
                        url: `kskCheckSoLuuTru-tt32?dvtt=${encodeURIComponent(dvttVal)}&mabenhnhan=${encodeURIComponent(mabenhnhan)}&sovaovien=${encodeURIComponent(sovaovien)}&loaiksk=ksk_du18`,
                        type: 'GET'
                    })
                ]);

                if (!field || !field.HOTEN) {
                    warn('API Mode: Không lấy được dữ liệu bệnh nhân — Fallback UI');
                    return null;
                }

                // Kiểm tra & chuẩn hóa CCCD
                let cccd = String(field.SOCMND || '').replace(/\s+/g, '').trim();
                const fixedCccd = fixCmnd(cccd);
                if (!fixedCccd) {
                    if (CFG.skipInvalidCccd) {
                        warn(`[API] CCCD không hợp lệ ("${cccd}", độ dài: ${cccd.length}) → Bỏ qua ca khám`);
                        return 'bad_cmnd';
                    }
                } else {
                    if (fixedCccd !== cccd) {
                        log(`[API] Tự động thêm 0 vào đầu CCCD: ${cccd} → ${fixedCccd}`);
                    }
                    cccd = fixedCccd;
                }

                // Bổ sung địa chỉ
                let diachi = String(field.DIACHI || '').trim();
                const diaChiThem = CFG.diaChiThem || 'P. Long Châu';
                if (!isAddressComplete(diachi, diaChiThem)) {
                    diachi = diachi ? `${diachi}, ${diaChiThem}` : diaChiThem;
                }

                // Ngày khám
                let ngayKham = String(field.NGAY_VAO || '').trim();
                if (!ngayKham) {
                    const now = new Date();
                    ngayKham = ('0' + now.getDate()).slice(-2) + '/' + ('0' + (now.getMonth() + 1)).slice(-2) + '/' + now.getFullYear();
                }

                // Bước 2: Cập nhật chỉ số sinh tồn (KSK_UPD_CSST_TT32)
                log('⚡ [API Mode] Bước 2/4: Cập nhật sinh hiệu KSK (KSK_UPD_CSST_TT32)...');
                const csstRes = await $.ajax({
                    url: 'cmu_post',
                    type: 'POST',
                    data: {
                        url: [
                            dvttVal, mabenhnhan, sovaovien,
                            v.chieucao, v.cannang, v.bmi,
                            v.huyetaptren, v.huyetapduoi, v.mach,
                            field.M123KETLUANSK || '',
                            'KSK_UPD_CSST_TT32'
                        ].join('```')
                    }
                });

                if (String(csstRes || '').trim() === '0') {
                    warn('API Mode: KSK_UPD_CSST_TT32 trả về 0 — Fallback UI');
                    return null;
                }

                // Bước 3: Xây dựng payload JSON chuẩn builtThongTinKhamSucKhoeDu18TT32()
                const dt = doiTuongTheoTuoi(age);
                const nguonChiTra = field.NGUON_CHI_TRA || getNguonChiTra(dt);
                const bsId = CFG.maBacSi;
                const bsDefaultText = getBsOptionText('tt32_mau2bacsituanhoan', bsId) || CFG.tenBacSi || '';
                const noiDungChung = CFG.noiDungLamSang || 'Chưa phát hiện bệnh lý';
                const noiDungTH = CFG.noiDungTuanHoan || 'Chưa phát hiện bệnh lý';

                const payload = {
                    DVTT: dvttVal,
                    SOVAOVIEN: sovaovien,
                    MABENHNHAN: mabenhnhan,
                    HOTEN: field.HOTEN || '',
                    GIOITINH: field.GIOITINH || (isNu ? '0' : '1'),
                    TUOI: String(field.TUOI || age),
                    SOCMND: cccd,
                    NGAYCAPCMND: String(field.NGAYCAPCMND || '').trim(),
                    NOICAPCMND: field.NOICAPCMND || '',
                    NGUOILIENHE: field.NGUOILIENHE || '',
                    DIACHI: diachi,
                    LYDOKHAMSK: CFG.lyDoKham || 'Kiểm tra khám sàng lọc',
                    ID_HOSO: String(soLuuTruRaw || '').trim(),
                    LOAIKSK: 'ksk_du18',

                    MA_DAN_TOC: field.MA_DANTOC || '01',
                    MA_NGHE_NGHIEP: field.MA_NGHE_NGHIEP || '1',
                    DOI_TUONG: dt,
                    NGUON_CHI_TRA: nguonChiTra,
                    NHOM_MAU: field.NHOM_MAU || '',
                    NOICONGTAC: field.NOI_LAM_VIEC || '',

                    GDBENHBAMSINH: field.GDBENHBAMSINH || '0',
                    GDTENBENHBAMSINH: field.GDTENBENHBAMSINH || 'Không',
                    BTTSBENHTAT: field.BTTSBENHTAT || '0',
                    BTTSTENBENH: field.BTTSTENBENH || 'Không',
                    BTDANGDT: field.BTDANGDT || 'Không',
                    BTTHAISAN: isNu ? (field.BTTHAISAN || 'Bình thường') : (field.BTTHAISAN || ''),
                    BT22_CT_BENH: field.BT22_CT_BENH || '',

                    CHIEUCAO: String(v.chieucao),
                    CANNANG: String(v.cannang),
                    BMI: String(v.bmi),
                    HUYETAPDUOI: String(v.huyetapduoi),
                    HUYETAPTREN: String(v.huyetaptren),
                    MACH: String(v.mach),
                    PHANLOAITHELUC: field.PHANLOAITHELUC || '',

                    TUANHOAN: noiDungTH,
                    TUANHOANKETLUAN: field.TUANHOANKETLUAN || '',
                    TUANHOANBS: bsId,
                    TUANHOANBS_TEN: getBsOptionText('tt32_mau2bacsituanhoan', bsId) || bsDefaultText,

                    HOHAP: noiDungChung,
                    HOHAPKETLUAN: field.HOHAPKETLUAN || '',
                    HOHAPBS: bsId,
                    HOHAPBS_TEN: getBsOptionText('tt32_mau2bacsihohap', bsId) || bsDefaultText,

                    TIEUHOA: noiDungChung,
                    TIEUHOAKETLUAN: field.TIEUHOAKETLUAN || '',
                    TIEUHOABS: bsId,
                    TIEUHOABS_TEN: getBsOptionText('tt32_mau2bacsitieuhoa', bsId) || bsDefaultText,

                    THANTIETNIEU: noiDungChung,
                    THANTIETNIEUKETLUAN: field.THANTIETNIEUKETLUAN || '',
                    THANTIETNIEUBS: bsId,
                    THANTIETNIEUBS_TEN: getBsOptionText('tt32_mau2bacsitietnieu', bsId) || bsDefaultText,

                    COXUONGKHOP: noiDungChung,
                    COXUONGKHOPKETLUAN: field.COXUONGKHOPKETLUAN || '',
                    COXUONGKHOPBS: bsId,
                    COXUONGKHOPBS_TEN: getBsOptionText('tt32_mau2bacsixuongkhop', bsId) || bsDefaultText,

                    THANKINH: noiDungChung,
                    THANKINHKETLUAN: field.THANKINHKETLUAN || '',
                    THANKINHBS: bsId,
                    THANKINHBS_TEN: getBsOptionText('tt32_mau2bacsithankinh', bsId) || bsDefaultText,

                    TAMTHAN: noiDungChung,
                    TAMTHANKETLUAN: field.TAMTHANKETLUAN || '',
                    TAMTHANBS: bsId,
                    TAMTHANBS_TEN: getBsOptionText('tt32_mau2bacsitamthan', bsId) || bsDefaultText,

                    NGOAIKHOA: noiDungChung,
                    NGOAIKHOAKETLUAN: field.NGOAIKHOAKETLUAN || '',
                    NGOAIKHOABS: bsId,
                    NGOAIKHOABS_TEN: getBsOptionText('tt32_mau2bacsingoaikhoa', bsId) || bsDefaultText,

                    DALIEU: noiDungChung,
                    DALIEUKETLUAN: field.DALIEUKETLUAN || '',

                    SANPHUKHOA: isNu ? noiDungChung : '',
                    SANPHUKHOAKETLUAN: field.SANPHUKHOAKETLUAN || '',
                    SANPHUKHOABS: isNu ? bsId : '0',
                    SANPHUKHOABS_TEN: isNu ? (getBsOptionText('tt32_mau2bacsiphukhoa', bsId) || bsDefaultText) : '',

                    NOITIET: noiDungChung,
                    NOITIETKETLUAN: field.NOITIETKETLUAN || '',
                    NOITIETBS: bsId,
                    NOITIETBS_TEN: getBsOptionText('tt32_mau2bacsinoitiet', bsId) || bsDefaultText,

                    KHONGKINH_MATPHAI: CFG.chiSoThiLuc || '10/10',
                    KHONGKINH_MATTRAI: CFG.chiSoThiLuc || '10/10',
                    COKINH_MATPHAI: field.COKINH_MATPHAI || '',
                    COKINH_MATTRAI: field.COKINH_MATTRAI || '',
                    BENHVEMAT: CFG.noiDungMat || 'Bình thường',
                    MATBS: bsId,
                    MATBS_TEN: getBsOptionText('tt32_mau2bacsimat', bsId) || bsDefaultText,
                    MATKETLUAN: field.MATKETLUAN || '',

                    TAITRAI_NOITHUONG: CFG.chiSoTaiThuong || '5m',
                    TAITRAI_NOITHAM: CFG.chiSoTaiTham || '0.5m',
                    TAIPHAI_NOITHUONG: CFG.chiSoTaiThuong || '5m',
                    TAIPHAI_NOITHAM: CFG.chiSoTaiTham || '0.5m',
                    BENHVETAI: CFG.noiDungTai || 'Bình thường',
                    BACSITAIMUIHONG: bsId,
                    BACSITAIMUIHONG_TEN: getBsOptionText('tt32_mau2bacsitaimuihong', bsId) || bsDefaultText,
                    TAIKETLUAN: field.TAIKETLUAN || '',

                    HAMTREN: 'Bình thường',
                    HAMDUOI: 'Bình thường',
                    BENHVERANG: CFG.noiDungRang || 'Bình thường',
                    BENHVERANGBS: bsId,
                    BENHVERANGBS_TEN: getBsOptionText('tt32_mau2bacsiranghammat', bsId) || bsDefaultText,
                    RANGKETLUAN: field.RANGKETLUAN || '',

                    M12PHANLOAISK: field.M12PHANLOAISK || '',
                    M123KETLUANSK: field.M123KETLUANSK || '',

                    HHTONG_PTTB_MAU: field.HHTONG_PTTB_MAU || '',
                    M2_SLHONGCAU: field.M2_SLHONGCAU || '',
                    M2_SLBACHCAU: field.M2_SLBACHCAU || '',
                    M2_SLTIEUCAU: field.M2_SLTIEUCAU || '',
                    M2_DUONGMAU: field.M2_DUONGMAU || '',
                    M2_URE: field.M2_URE || '',
                    M2_CREATEMIN: field.M2_CREATEMIN || '',
                    M2_GOT: field.M2_GOT || '',
                    M2_GPT: field.M2_GPT || '',
                    M2_XNKHAC: field.M2_XNKHAC || '',
                    XN_NUOCTIEU_CLS_TK: field.XN_NUOCTIEU_CLS_TK || '',
                    M2_DUONGNUOCTIEU: field.M2_DUONGNUOCTIEU || '',
                    M2_PROTEINNUOCTIEU: field.M2_PROTEINNUOCTIEU || '',
                    M2_KHACNUOCTIEU: field.M2_KHACNUOCTIEU || '',
                    M2M3_CDHA: field.M2M3_CDHA || '',
                    M2_CTMAUBS: field.M2_CTMAUBS || '0',
                    M2_CTMAUBS_TEN: '',
                    M2M3_CDHA_BS: field.M2M3_CDHA_BS || '0',
                    M2M3_CDHA_BS_TEN: '',
                    M2_NUOCTIEU_BS: field.M2_NUOCTIEU_BS || '0',
                    M2_NUOCTIEU_BS_TEN: '',
                    CLS_KHAC: field.CLS_KHAC || '',
                    CLS_KHAC_BS: field.CLS_KHAC_BS || '0',
                    CLS_KHAC_BS_TEN: '',
                    CLS_THEOBS: field.CLS_THEOBS || '',
                    CLS_THEOBS_BS: field.CLS_THEOBS_BS || '0',
                    CLS_THEOBS_BS_TEN: ''
                };

                for (let i = 1; i <= 22; i++) {
                    payload['BT' + i] = field['BT' + i] != null ? String(field['BT' + i]) : '0';
                }

                // Bước 3: Gửi PUT lưu toàn bộ phiếu KSK
                log(`⚡ [API Mode] Bước 3/4: Lưu phiếu KSK (PUT .../tt32/${stt})...`);
                await $.ajax({
                    type: 'PUT',
                    url: `insertkhamsuckhoethongtindu18-tt32/${stt}`,
                    data: JSON.stringify(payload),
                    contentType: 'application/json'
                });

                // Bước 4: Cập nhật hành chính & trạng thái bác sĩ KSK song song
                log('⚡ [API Mode] Bước 4/4: Đồng bộ hành chính & trạng thái KSK...');
                const bsDalieuText = getBsOptionText('tt32_mau2bacsidalieu', bsId) || bsDefaultText;
                const bsShort = bsDalieuText.split('-')[1] ? bsDalieuText.split('-')[1].trim() : bsDalieuText;

                await Promise.all([
                    $.post('cmu_post', {
                        url: [
                            dvttVal, mabenhnhan, sovaovien,
                            payload.GIOITINH, cccd, payload.NGAYCAPCMND, payload.NOICAPCMND,
                            payload.MA_DAN_TOC, payload.MA_NGHE_NGHIEP, diachi,
                            payload.NGUOILIENHE, ngayKham,
                            'KSK_UPD_TTHC_TT32'
                        ].join('```')
                    }),
                    $.post('cmu_post', {
                        url: [dvttVal, mabenhnhan, sovaovien, 3, 'VLG_UPD_TT_KSK'].join('```')
                    }),
                    $.post('cmu_post', {
                        url: [dvttVal, mabenhnhan, sovaovien, bsId, bsShort, 'VLG_UPD_NGAYSUA_KSK'].join('```')
                    })
                ]);

                success('⚡ [API Mode] Đã lưu phiếu KSK siêu tốc thành công!');
                return true;
            } catch (err) {
                warn(`API Mode gặp lỗi (${err && (err.statusText || err.message || err.status)}) — Tự động chuyển sang UI Mode`);
                return null;
            }
        }

        async function fillKsk(age, v, isNu = false) {
            if (CFG.apiMode) {
                const apiRet = await fillKskViaApi(age, v, isNu);
                if (apiRet === 'bad_cmnd') return 'bad_cmnd';
                if (apiRet === true) return true;
            }

            await guardReady('KSK');
            log('→ Mở phiếu KSK đủ 18 tuổi (#khamsuckhoetheodoituongdu18)');
            $('#khamsuckhoetheodoituongdu18').click();

            if (!(await waitKskLoad(CFG.kskLoadTimeout))) {
                warn('Phiếu KSK không nạp xong');
                return false;
            }

            if (!applyCmndOrFail()) return 'bad_cmnd';

            const dt = doiTuongTheoTuoi(age);
            log(`Điền đối tượng KSK = ${dt}`);
            setVal('tt32_mau2kskdoituong', dt);
            $('#tt32_mau2kskdoituong').trigger('change');
            await sleep(100);

            setVal('tt32_mau2ksklydo', CFG.lyDoKham || 'Kiểm tra khám sàng lọc');
            patchDiaChi();

            // Sinh hiệu trong phiếu KSK
            setVal('tt32_mau2chieucao', v.chieucao);
            setVal('tt32_mau2cannang', v.cannang);
            setVal('tt32_mau2kskmach', v.mach);
            setVal('tt32_mau2kskhuyetapcao', v.huyetaptren);
            setVal('tt32_mau2kskhuyetapthap', v.huyetapduoi);
            if ($('#tt32_mau2bmi').length) setVal('tt32_mau2bmi', v.bmi);

            try {
                if (typeof tt32_loadchiso_mau2 === 'function') tt32_loadchiso_mau2();
            } catch (e) { }

            // Chuyển sang Tab 3 Khám lâm sàng
            log('→ Chuyển sang tab Khám lâm sàng');
            const tab3 = document.querySelector('a[href*="tt32_mau2ksk-tab3"]') || document.getElementById('tt32_mau2ksk_tab3');
            if (tab3) tab3.click();
            else $('#tt32_mau2ksk_tab3').click();

            await sleep(150);

            if (!(await fillLamSangVerified(isNu))) {
                warn('Chưa điền xong lâm sàng/bác sĩ — Không thể lưu KSK');
                return false;
            }

            // Kiểm tra lại đối tượng
            if (String($('#tt32_mau2kskdoituong').val() || '') !== String(dt)) {
                setVal('tt32_mau2kskdoituong', dt);
                $('#tt32_mau2kskdoituong').trigger('change');
                await sleep(60);
            }

            closeChosenDrops();
            await sleep(CFG.stepDelay);

            log('→ Bấm Lưu phiếu KSK (#tt32_mau2luuthongtin)');
            $('#tt32_mau2luuthongtin').click();
            await clickDongY(2000);

            log('→ Đóng hộp thoại KSK');
            closeKskDialog();
            await sleep(150);
            await clickDongY(400);
            await waitIdle(2000, CFG.quietDelay);

            if ($('#tt32_mau2_khamkstheomau_div').is(':visible')) {
                closeKskDialog();
                await sleep(100);
            }
            success('Đã lưu và đóng phiếu KSK thành công!');
            return true;
        }

        // =========================================================================
        // 7. KÝ SỐ SMARTCA & CƠ CHẾ PHÁT HIỆN MENU ĐĂNG NHẬP SMARTCA
        // =========================================================================
        function isSmartCALoginAppeared() {
            // 1. Kiểm tra div modal đăng nhập theo ID
            const loginDiv = document.querySelector('#pdf-modal-signature-login');
            if (loginDiv) {
                const dialog = loginDiv.closest('.ui-dialog');
                if (dialog && dialog.offsetParent !== null && window.getComputedStyle(dialog).display !== 'none') {
                    return loginDiv;
                }
            }

            // 2. Kiểm tra tiêu đề modal chứa text "ĐĂNG NHẬP SMARTCA"
            const titles = Array.from(document.querySelectorAll('.ui-dialog-title'));
            for (let t of titles) {
                const txt = stripVn(t.textContent || '');
                if (txt.includes('dang nhap smartca') || txt.includes('dang nhap smart ca')) {
                    const dialog = t.closest('.ui-dialog');
                    if (dialog && dialog.offsetParent !== null && window.getComputedStyle(dialog).display !== 'none') {
                        return t;
                    }
                }
            }

            // 3. Kiểm tra các form đăng nhập SmartCA phổ biến khác
            const otherLogin = document.querySelector('#smartca-login-modal, #form-login-smartca, .smartca-login-container');
            if (otherLogin && otherLogin.offsetParent !== null && window.getComputedStyle(otherLogin).display !== 'none') {
                return otherLogin;
            }

            return null;
        }

        function closeSmartCALoginModal() {
            try {
                const loginModal = $('#pdf-modal-signature-login').closest('.ui-dialog');
                if (loginModal.length) {
                    const closeBtn = loginModal.find('.ui-dialog-titlebar-close');
                    if (closeBtn.length) closeBtn.click();
                    else loginModal.hide();
                }
                if (window.$ && $('#pdf-modal-signature-login').dialog) {
                    try { $('#pdf-modal-signature-login').dialog('close'); } catch (e) { }
                }

                const titles = Array.from(document.querySelectorAll('.ui-dialog-title'));
                for (let t of titles) {
                    const txt = stripVn(t.textContent || '');
                    if (txt.includes('dang nhap smartca') || txt.includes('dang nhap smart ca')) {
                        const d = t.closest('.ui-dialog');
                        if (d) {
                            const c = d.querySelector('.ui-dialog-titlebar-close');
                            if (c) c.click();
                            else d.style.display = 'none';
                        }
                    }
                }
            } catch (e) { }
        }

        function setSigningEnabled(enabled, reason = '') {
            CFG.enableKySo = !!enabled;
            const $chip = $('#ksk_chip_kyso');
            if ($chip.length) {
                $chip.toggleClass('active', CFG.enableKySo);
                $chip.find('strong').text(CFG.enableKySo ? '🔐 BẬT' : '🔓 TẮT');
                if (reason) $chip.attr('title', `Ký số: ${CFG.enableKySo ? 'BẬT' : 'TẮT'} (${reason})`);
            }
            saveConfigToStorage();
        }

        function onSmartCaLoginDetected() {
            warn('🚨 PHÁT HIỆN MENU ĐĂNG NHẬP SMARTCA! Tài khoản chưa đăng nhập hoặc phiên làm việc đã hết hạn.');
            closeSmartCALoginModal();
            closeSmartCaModal();

            if (CFG.autoDisableOnLoginAlert) {
                setSigningEnabled(false, 'Phát hiện menu Đăng nhập SmartCA');
                warn('🔓 Đã TỰ ĐỘNG TẮT ký số SmartCA để hệ thống tiếp tục tự động khám.');
                setStatus('Phát hiện Đăng nhập SmartCA → Đã tắt ký số để tiếp tục.');
            }
            return 'LOGIN_DETECTED';
        }

        function kysoDaKy(mayte, role) {
            return !!(mayte && KYSO_DONE[mayte] && KYSO_DONE[mayte][role]);
        }

        function kysoDu2(mayte) {
            return kysoDaKy(mayte, CFG.vaiTro1) && kysoDaKy(mayte, CFG.vaiTro2);
        }

        function markKyso(mayte, role) {
            if (!mayte) return;
            if (!KYSO_DONE[mayte]) KYSO_DONE[mayte] = {};
            KYSO_DONE[mayte][role] = 1;
        }

        function smartCaModalOpen() {
            const $c = $('#smartca-ad-modal-container');
            if ($c.length && $c.hasClass('one') && !$c.hasClass('out')) return true;
            if ($('#smartca-ad-modal').is(':visible')) return true;
            if ($('#smartca-ad-grid-thong-tin-phieu').closest(':visible').length) return true;
            return false;
        }

        function closeSmartCaModal() {
            closeSmartCALoginModal();
            try {
                $('#smartca-alert .smartca-alert-button-confirm:visible').each(function () { this.click(); });
            } catch (e) { }
            try {
                if ($('#smartca-ad-modal-select-vai-tro-sign-xml').hasClass('ui-dialog-content')) {
                    $('#smartca-ad-modal-select-vai-tro-sign-xml').dialog('close');
                }
            } catch (e) { }
            try {
                if ($('#smartca-ad-modal-select-vai-tro').hasClass('ui-dialog-content')) {
                    $('#smartca-ad-modal-select-vai-tro').dialog('close');
                }
            } catch (e) { }
            try {
                $('[aria-describedby=smartca-ad-modal-select-vai-tro-sign-xml]').find('.ui-dialog-titlebar-close').click();
            } catch (e) { }
            try {
                const $x = $('#smartca-ad-modal-close-button');
                if ($x.length) $x[0].click();
            } catch (e) { }
            try {
                $('#smartca-ad-modal-container').addClass('out').removeClass('one');
                $('body').css('overflow', 'auto');
            } catch (e) { }
        }

        function findTabKhac() {
            const $t = $('#smartca-tab-item-khac');
            if ($t.length) return $t.first();
            return $('.smartca-ad-modal-content-tabs-header-item').filter(function () {
                return /khac/.test(stripVn($(this).text() || ''));
            }).first();
        }

        function tabKhacActive($tab) {
            $tab = $tab || findTabKhac();
            if (!$tab.length) return false;
            if ($tab.hasClass('smartca-ad-modal-content-tabs-header-active')) return true;
            try {
                if (typeof currentTabId !== 'undefined' && currentTabId === 'smartca-tab-item-khac') return true;
            } catch (e) { }
            return false;
        }

        async function goTabKhac(maxMs = 6000) {
            log('→ Chờ/chuyển sang tab "Khác" trong bảng SmartCA...');
            const t0 = Date.now();
            while (Date.now() - t0 < maxMs) {
                if (STOP) return false;
                if (isSmartCALoginAppeared()) {
                    onSmartCaLoginDetected();
                    return false;
                }
                const $tab = findTabKhac();
                if ($tab.length) {
                    $('.smartca-ad-modal-content-tabs-header-item').css('pointer-events', 'auto');
                    if (!tabKhacActive($tab)) {
                        $tab.trigger('click');
                        await sleep(200);
                    }
                    if (tabKhacActive($tab)) {
                        log('✓ Đang ở tab "Khác"');
                        return true;
                    }
                }
                await sleep(150);
            }
            warn('Không kích hoạt được tab "Khác"');
            return false;
        }

        function findKskSignBtn() {
            let $b = $('.smartca-ad-sign-button-scanner[data-type="btn-ky-so"][data-id="XML_KSK_DINH_KY_TREN_18_TUOI"]');
            if ($b.length) return $b.first();
            $b = $('div[data-type="btn-ky-so"][data-id="XML_KSK_DINH_KY_TREN_18_TUOI"]');
            if ($b.length) return $b.first();
            $b = $('div[data-type="btn-ky-so"]').filter(function () {
                const id = String($(this).attr('data-id') || '');
                return /KSK/.test(id) && /18/.test(id);
            });
            return $b.first();
        }

        async function waitKskSignBtn(maxMs = 5000) {
            const totalWait = Math.min(maxMs || CFG.kysoGridWaitMs, 8000);
            const t0 = Date.now();
            const firstWait = Math.min(3000, totalWait);

            async function waitUntil(deadline) {
                while (Date.now() < deadline) {
                    if (STOP) return null;
                    if (isSmartCALoginAppeared()) {
                        onSmartCaLoginDetected();
                        return null;
                    }
                    const $b = findKskSignBtn();
                    if ($b.length && $b.is(':visible')) return $b;
                    await sleep(100);
                }
                return null;
            }

            let $signBtn = await waitUntil(t0 + firstWait);
            if ($signBtn && $signBtn.length) return $signBtn;

            if (STOP) return null;
            if (isSmartCALoginAppeared()) {
                onSmartCaLoginDetected();
                return null;
            }
            const $reload = $('#reloads:visible').first();
            if ($reload.length) {
                $reload[0].click();
                log('Chưa thấy nút ký — Đã bấm nạp lại (#reloads)...');
            }

            $signBtn = await waitUntil(t0 + totalWait);
            return ($signBtn && $signBtn.length) ? $signBtn : null;
        }

        async function openSmartCaFloat() {
            if (isSmartCALoginAppeared()) {
                onSmartCaLoginDetected();
                return false;
            }
            log('→ Mở hộp thoại SmartCA qua nút nổi Scanner');
            const $btn = $('#smartca-ad-float-button-scanner');
            if (!$btn.length) {
                warn('Không thấy nút nổi #smartca-ad-float-button-scanner');
                return false;
            }
            $btn[0].click();

            const t0 = Date.now();
            while (Date.now() - t0 < 8000) {
                if (isSmartCALoginAppeared()) {
                    onSmartCaLoginDetected();
                    return false;
                }
                if (smartCaModalOpen()) break;
                await sleep(150);
            }
            if (!smartCaModalOpen()) {
                warn('Hộp thoại SmartCA không mở được');
                return false;
            }
            await goTabKhac(6000);
            return true;
        }

        async function waitRoleDialog(maxMs = 8000) {
            const t0 = Date.now();
            while (Date.now() - t0 < maxMs) {
                if (isSmartCALoginAppeared()) {
                    onSmartCaLoginDetected();
                    return null;
                }
                if ($('[aria-describedby=smartca-ad-modal-select-vai-tro-sign-xml]').is(':visible') || $('#slb-vai-tro-sign-xml:visible').length) return 'xml';
                if ($('[aria-describedby=smartca-ad-modal-select-vai-tro]').is(':visible')) return 'vnpt';
                try {
                    if ($('#smartca-ad-modal-select-vai-tro-sign-xml').hasClass('ui-dialog-content') && $('#smartca-ad-modal-select-vai-tro-sign-xml').dialog('isOpen')) return 'xml';
                } catch (e) { }
                await sleep(80);
            }
            return null;
        }

        function selectVaiTroXml(roleVal) {
            const el = document.getElementById('slb-vai-tro-sign-xml');
            if (!el) return false;
            const $sel = $(el);
            $sel.find('option').each(function () { this.selected = false; });

            let ok = false;
            $sel.find('option').each(function () {
                if (String(this.value) === String(roleVal)) {
                    this.selected = true;
                    ok = true;
                    return false;
                }
            });

            if (!ok) {
                const want = roleVal === 'CKS_BENH_VIEN' ? /chu\s*ky\s*benh\s*vien|benh\s*vien/ : /nguoi\s*ket\s*luan|ket\s*luan/;
                $sel.find('option').each(function () {
                    if (want.test(stripVn(this.textContent || ''))) {
                        this.selected = true;
                        roleVal = this.value;
                        ok = true;
                        return false;
                    }
                });
            }

            el.value = roleVal;
            $sel.val(roleVal);
            triggerEvent(el, 'change');
            triggerEvent(el, 'input');
            $sel.trigger('change').trigger('chosen:updated');
            return String(el.value) === String(roleVal);
        }

        async function confirmAfterSign(label, maxMs = null) {
            maxMs = maxMs || CFG.kysoWaitMs;
            log(`⏳ Chờ xác nhận ký số «${label}» (tối đa ${Math.round(maxMs / 1000)}s)...`);
            const t0 = Date.now();

            while (Date.now() - t0 < maxMs) {
                if (STOP) return false;
                if (isSmartCALoginAppeared()) {
                    onSmartCaLoginDetected();
                    return 'LOGIN_DETECTED';
                }
                const elapsed = Math.round((Date.now() - t0) / 1000);
                setStatus(`Chờ xác nhận ký «${label}»... ${elapsed}s`);

                const $alert = $('#smartca-alert:visible');
                if ($alert.length) {
                    const $ok = $alert.find('.smartca-alert-button-confirm:visible').first();
                    if ($ok.length) {
                        const txt = ($alert.find('.smartca-alert-content').text() || '').trim();
                        $ok[0].click();
                        const normTxt = stripVn(txt);
                        if (/loi|that bai|khong thanh cong|da huy|chua ky|chua cau hinh|khong the/.test(normTxt)) {
                            warn(`Cảnh báo ký «${label}»: ${txt.slice(0, 80)}`);
                            await sleep(200);
                            return false;
                        }
                        success(`Đã xác nhận ký «${label}»: ${txt.slice(0, 60)}`);
                        await sleep(200);
                        return true;
                    }
                }
                await clickDongY(150);
                await sleep(CFG.pollInterval);
            }
            warn(`Timeout chờ xác nhận ký «${label}»`);
            return false;
        }

        async function kyMotVaiTro(roleVal, roleLabel) {
            const mayte = bnMayte();
            if (kysoDaKy(mayte, roleVal)) {
                log(`⏭ Bỏ qua vai trò «${roleLabel}» — BN ${mayte} đã ký rồi`);
                return true;
            }

            if (isSmartCALoginAppeared()) {
                onSmartCaLoginDetected();
                return 'LOGIN_DETECTED';
            }

            log(`→ Bắt đầu ký vai trò «${roleLabel}» (${roleVal})`);
            const $btn = findKskSignBtn();
            if (!$btn.length) {
                warn('Không thấy nút ký số XML_KSK');
                return false;
            }
            $btn[0].click();

            const kind = await waitRoleDialog(8000);
            if (!kind) {
                if (isSmartCALoginAppeared()) return 'LOGIN_DETECTED';
                warn('Hộp thoại chọn vai trò ký không mở');
                return false;
            }

            await sleep(100);
            selectVaiTroXml(roleVal);
            await sleep(100);

            log(`✓ Đã chọn vai trò «${roleLabel}» → Bấm KÝ SỐ`);
            const $ky = kind === 'xml' ? $('#btn-ky-so-xml-ca') : $('#btn-ky-so-vnpt-ca');
            if (!$ky.length) {
                warn('Không tìm thấy nút bấm ký số');
                return false;
            }
            $ky[0].click();

            const confRet = await confirmAfterSign(roleLabel);
            if (confRet === 'LOGIN_DETECTED') return 'LOGIN_DETECTED';
            if (!confRet) return false;

            markKyso(mayte, roleVal);
            success(`Đã hoàn tất ký vai trò «${roleLabel}»!`);
            return true;
        }

        function formatNowVN() {
            if (typeof window.moment === 'function') {
                return window.moment().format('DD/MM/YYYY HH:mm:ss');
            }
            const d = new Date();
            const pad = n => String(n).padStart(2, '0');
            return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
        }

        async function kySoViaApi() {
            if (!CFG.enableKySo) {
                log('Ký số SmartCA đang TẮT trong cấu hình, bỏ qua bước ký');
                return true;
            }
            if (isSmartCALoginAppeared()) {
                onSmartCaLoginDetected();
                return 'LOGIN_DETECTED';
            }
            if (!dangNhapLieu()) {
                warn('Không ở trạng thái khám/sửa — Bỏ qua ký số');
                return false;
            }

            const mayte = bnMayte();
            if (kysoDu2(mayte)) {
                log(`BN ${mayte} đã có đủ 2 chữ ký số — Bỏ qua ký`);
                return true;
            }

            const dvttVal = typeof window.Sess_DVTT !== 'undefined' ? window.Sess_DVTT : (typeof window.dvtt !== 'undefined' ? window.dvtt : '');
            const sessUser = typeof window.Sess_User !== 'undefined' ? window.Sess_User : '';
            const maBenhNhan = ($('#mayte').val() || mayte || '').trim();
            const soVaoVien = ($('#sovaovien').val() || '').trim();
            const maKhamBenh = ($('#makb').val() || $('#makb_hid').val() || '-1').trim() || '-1';

            if (!dvttVal || !maBenhNhan || !soVaoVien) {
                warn('[SmartCA API] Thiếu thông tin (dvtt/maBenhNhan/soVaoVien) — Chuyển sang UI Mode');
                return false;
            }

            log(`===== ⚡ [SmartCA API] BẮT ĐẦU KÝ SỐ BN ${maBenhNhan} =====`);

            try {
                // 1. Tải thông tin bệnh nhân SmartCA (không mở modal)
                const patientInfo = await $.ajax({
                    type: 'GET',
                    contentType: 'application/json',
                    dataType: 'json',
                    url: 'smartca-ad-get-info-patient?' + $.param({
                        maBenhNhan: maBenhNhan,
                        maKhamBenh: maKhamBenh,
                        soVaoVien: soVaoVien,
                        soVaoVienDt: '-1',
                        soBenhAn: '-1',
                        sttBenhAn: '-1',
                        sttDotDieuTri: '-1',
                        noiTru: '0'
                    })
                });

                const bnMa = (patientInfo && patientInfo.MA_BENH_NHAN) || maBenhNhan;
                const bnSvv = (patientInfo && patientInfo.SO_VAO_VIEN) || soVaoVien;
                const bnSptt = (window.thongTinBenhNhan && window.thongTinBenhNhan.soPhieuThanhToan !== undefined)
                    ? window.thongTinBenhNhan.soPhieuThanhToan
                    : null;

                // 2. Lấy metadata phiếu XML_KSK_DINH_KY_TREN_18_TUOI (kiểm tra cả chưa ký & đã ký 1 phần)
                const kyHieuTarget = 'XML_KSK_DINH_KY_TREN_18_TUOI';
                let phieuRow = null;
                for (const ttKy of ['0', '1']) {
                    const listSign = await $.ajax({
                        type: 'GET',
                        contentType: 'application/json',
                        dataType: 'json',
                        url: 'smartca-ad-get-list-sign?' + $.param({
                            noiTru: '0',
                            trangThaiKy: ttKy,
                            maBenhNhan: bnMa,
                            soVaoVien: bnSvv,
                            soVaoVienDieuTri: '-1',
                            sttBenhAn: '-1',
                            soBenhAn: '-1',
                            sttDieuTri: '-1',
                            sttDotDieuTri: '-1',
                            loaiPhieu: 'khac'
                        })
                    });
                    if (Array.isArray(listSign)) {
                        phieuRow = listSign.find(x => x && x.KY_HIEU_PHIEU === kyHieuTarget) || null;
                        if (phieuRow) break;
                    }
                }

                if (!phieuRow) {
                    warn(`[SmartCA API] Không tìm thấy phiếu ${kyHieuTarget} trong danh sách ký — Chuyển sang UI Mode`);
                    return false;
                }

                // 3. Kiểm tra & tự mở khóa nếu phiếu đang bị lock bởi chính user hiện tại
                const lockParams = {
                    noiTru: 0,
                    maBenhNhan: bnMa,
                    soVaoVien: bnSvv,
                    soBenhAn: '-1',
                    kyHieuPhieu: kyHieuTarget
                };
                const lockRes = await Promise.resolve($.ajax({
                    type: 'GET',
                    dataType: 'json',
                    url: 'smartca-get-phieu-lock?' + $.param(lockParams)
                })).catch(() => null);

                if (lockRes && lockRes.MA_NHAN_VIEN && lockRes.THOI_GIAN_LOCK) {
                    if (String(lockRes.MA_NHAN_VIEN) === String(phieuRow.MA_NHAN_VIEN || '')) {
                        const unlockPar = { ...lockParams, keySign: phieuRow.KEYSIGN || '' };
                        const canUnlock = await Promise.resolve($.ajax({
                            type: 'GET',
                            dataType: 'json',
                            url: 'smartca-check-transaction-status?' + $.param(unlockPar)
                        })).catch(() => false);
                        if (canUnlock) {
                            await Promise.resolve($.ajax({
                                type: 'GET',
                                dataType: 'json',
                                url: 'smartca-delete-phieu-lock?' + $.param(unlockPar)
                            })).catch(() => null);
                            log('✓ [SmartCA API] Đã tự động mở khóa phiếu cũ');
                        } else {
                            warn('[SmartCA API] Phiếu đang chờ xác nhận giao dịch cũ — Chuyển sang UI Mode');
                            return false;
                        }
                    } else {
                        warn(`[SmartCA API] Phiếu đang bị khóa bởi ${lockRes.TEN_NHAN_VIEN || lockRes.MA_NHAN_VIEN}`);
                        return false;
                    }
                }

                // 4. Chuẩn bị keyKcb, keyPrint, keySign (khớp initializePhieuKySo)
                const soPhieuDv = typeof window.getValueSoPhieuByKyHieuPhieu === 'function'
                    ? window.getValueSoPhieuByKyHieuPhieu(phieuRow)
                    : (phieuRow.SO_PHIEU || '');
                const loaiPhieu = typeof window.getLoaiPhieuKeyKcb === 'function'
                    ? window.getLoaiPhieuKeyKcb(kyHieuTarget)
                    : '';
                const maDichVuRaw = phieuRow.MA_DICH_VU;
                const maDichVu = (maDichVuRaw !== null && maDichVuRaw !== undefined && maDichVuRaw !== '' && maDichVuRaw !== 'null') ? maDichVuRaw : -1;

                const keyKcb = {
                    noiTru: 0,
                    maBenhNhan: bnMa,
                    soVaoVien: bnSvv,
                    toa: phieuRow.MA_TOA_THUOC || '',
                    maToaThuoc: phieuRow.MA_TOA_THUOC || '',
                    nghiepVuToaThuoc: phieuRow.NGHIEP_VU || '',
                    kyHieuPhieu: kyHieuTarget,
                    soPhieuThanhToan: bnSptt,
                    soPhieuDV: soPhieuDv,
                    soPhieuXetNghiem: soPhieuDv,
                    soPhieuCDHA: soPhieuDv,
                    maDichVu: maDichVu,
                    lanHoiChan: phieuRow.STT_HOI_CHAN || '',
                    giayChungSinhId: phieuRow.ID_PHIEU_CHUNG_SINH || '',
                    idTreSoSinh: phieuRow.ID_BE || '',
                    babyNumber: (phieuRow.STT_BE || phieuRow.SO_BE) ? (phieuRow.STT_BE || phieuRow.SO_BE) : -1,
                    loaiPhieu: loaiPhieu,
                    soPhieuDichVu: soPhieuDv,
                    kyHieuPhieuCha: phieuRow.KY_HIEU_PHIEU_CHA || '',
                    isPhieuCon: phieuRow.IS_PHIEU_CON || '0',
                    maKhoa: '',
                    tenKhoa: ''
                };

                const keyPrint = {
                    bant: phieuRow.BANT,
                    fileName: phieuRow.TEN_FILE || '',
                    dvtt: phieuRow.DVTT || dvttVal,
                    sendEmr: false,
                    trangThaiDDT: (patientInfo && patientInfo.TT_DOT_DIEU_TRI) || null,
                    nhapVienNgoaiTru: (patientInfo && patientInfo.NHAP_VIEN_NGOAI_TRU) || null,
                    lstIdPhieu: '',
                    ngayLapPdt: undefined,
                    tuNgay: undefined,
                    denNgay: undefined,
                    maPhongBan: undefined,
                    maKhamBenhNgoaiTru: undefined,
                    ngayVao: undefined
                };

                const sKeyKcb = JSON.stringify(keyKcb);
                const keySign = phieuRow.KEYSIGN ? phieuRow.KEYSIGN : (typeof $.md5 === 'function' ? $.md5(sKeyKcb) : '');
                if (!keySign) {
                    warn('[SmartCA API] Không tạo được keySign — Chuyển sang UI Mode');
                    return false;
                }

                const vaiTroMap = typeof window.VAI_TRO_CKS_XML_KSK !== 'undefined'
                    ? window.VAI_TRO_CKS_XML_KSK
                    : { CKS_NGUOI_KET_LUAN: 1, CKS_BENH_VIEN: 2 };
                const tagRefMap = typeof window.TAG_SIGNING_REFERENCE !== 'undefined'
                    ? window.TAG_SIGNING_REFERENCE
                    : { CKS_NGUOI_KET_LUAN: 'THONGTINDONVI', CKS_BENH_VIEN: 'THONGTINHOSO' };
                const cksDonViTags = typeof window.tagSigningCksDonVi !== 'undefined'
                    ? window.tagSigningCksDonVi
                    : ['CKS_BENH_VIEN', 'CHUKYDONVI', 'DU_PHONG'];
                const tongSoKy = typeof window.tongVaiTro !== 'undefined' ? window.tongVaiTro : 2;
                const urlSignHash = String(window.smartCA_950351 || '') === '4'
                    ? 'hsm-save-file-xml-signed-hash'
                    : 'smartca-save-file-xml-signed-hash-qd-769';
                const maKhoaSca = typeof window.maPhongBanSmartca !== 'undefined' ? window.maPhongBanSmartca : '';
                const chuKyBn = typeof window.base64ChuKyBenhNhan !== 'undefined' ? window.base64ChuKyBenhNhan : null;

                const rolesToSign = [
                    { key: CFG.vaiTro1 || 'CKS_NGUOI_KET_LUAN', label: 'Người kết luận' },
                    { key: CFG.vaiTro2 || 'CKS_BENH_VIEN', label: 'Chữ ký bệnh viện' }
                ];

                // 5. Thực hiện ký từng vai trò qua API
                for (const role of rolesToSign) {
                    if (STOP) return false;
                    if (kysoDaKy(mayte, role.key)) {
                        log(`⏭ [SmartCA API] Bỏ qua «${role.label}» — Đã ký`);
                        continue;
                    }

                    const vaiTroNum = vaiTroMap[role.key];
                    const daKyVaiTro = await $.post('cmu_post_SMARTCA_KT_VAITRO_SIGNED_XML', {
                        url: [dvttVal, kyHieuTarget, keySign, vaiTroNum].join('```')
                    });
                    if (Number(daKyVaiTro) > 0) {
                        log(`✓ [SmartCA API] Server xác nhận «${role.label}» đã ký trước đó`);
                        markKyso(mayte, role.key);
                        continue;
                    }

                    if (!cksDonViTags.includes(role.key)) {
                        const loginCheck = await $.ajax({ method: 'POST', url: 'smartca-check-login' });
                        if (loginCheck && (loginCheck.STATUS === 'NOTLOGIN' || loginCheck.STATUS === 'NOTAUTH')) {
                            warn(`[SmartCA API] SmartCA chưa đăng nhập (${loginCheck.STATUS})`);
                            onSmartCaLoginDetected();
                            return 'LOGIN_DETECTED';
                        }
                    }

                    const orderCheck = await $.post('cmu_post_SMARTCA_CHECK_ORDER_SIGN_XML', {
                        url: [dvttVal, keySign, vaiTroNum].join('```')
                    });
                    if (Number(orderCheck) > 0) {
                        warn(`[SmartCA API] Thứ tự ký không hợp lệ cho «${role.label}» (code=${orderCheck})`);
                        return false;
                    }

                    const fileState = await $.ajax({
                        method: 'POST',
                        url: `smartca-check-user-file-login-signed?keysign=${encodeURIComponent(keySign)}&type=XML`
                    });

                    const xmlStatus = fileState && fileState.XMLSTATUS;
                    let statusFileSignedApi = true;
                    let keyMinioApi = (fileState && fileState.XMLKEYMINIO) || null;
                    let objSignXmlApi;

                    if (role.key !== 'CKS_BENH_VIEN' && xmlStatus === 'NOTSIGNED') {
                        const objKcb = { ...keyPrint, ...keyKcb };
                        const dataObject = {
                            ...objKcb,
                            base64ChuKyBenhNhan: chuKyBn,
                            trangThaiDDT: keyPrint.trangThaiDDT,
                            nhapVienNgoaiTru: keyPrint.nhapVienNgoaiTru,
                            lstIdPhieu: keyPrint.lstIdPhieu,
                            maKhoa: maKhoaSca,
                            ngayLapPhieu: keyPrint.ngayLapPdt,
                            tuNgay: keyPrint.tuNgay,
                            denNgay: keyPrint.denNgay
                        };
                        const sObjKcb = JSON.stringify(dataObject);
                        log(`⚡ [SmartCA API] Tạo XML gốc cho «${role.label}» (send-xml-emr-ngoai-tru)...`);
                        const xmlGenRes = await $.ajax({
                            type: 'POST',
                            contentType: 'application/json',
                            dataType: 'json',
                            url: 'send-xml-emr-ngoai-tru',
                            data: sObjKcb
                        });
                        if (!xmlGenRes || String(xmlGenRes.errorCode) !== '1' || !xmlGenRes.contentFile || !xmlGenRes.contentFile.buffer) {
                            warn(`[SmartCA API] Không tạo được XML gốc (${(xmlGenRes && xmlGenRes.message) || 'rỗng'}) — Fallback UI`);
                            return false;
                        }
                        statusFileSignedApi = false;
                        keyMinioApi = null;
                        objSignXmlApi = {
                            xmlKey: typeof $.md5 === 'function' ? $.md5(sObjKcb) : null,
                            nameFile: keyPrint.fileName,
                            xmlFile: xmlGenRes.contentFile.buffer,
                            keySign: keySign,
                            keyKcb: sObjKcb,
                            kyHieuPhieu: kyHieuTarget
                        };
                    } else {
                        statusFileSignedApi = true;
                        objSignXmlApi = {
                            xmlKey: null,
                            nameFile: keyPrint.fileName,
                            xmlFile: null,
                            keySign: keySign,
                            keyKcb: sKeyKcb,
                            kyHieuPhieu: kyHieuTarget
                        };
                    }

                    const nameFileTs = `${kyHieuTarget}_${Math.round(Date.now())}`;
                    const signPayload = {
                        fullName: sessUser,
                        signDate: formatNowVN(),
                        base64ImageSign: null,
                        signTemplateList: null,
                        visibleType: '1',
                        base64PdfSign: null,
                        fontSize: 5,
                        keySign: keySign,
                        vaiTroKySo: vaiTroNum,
                        soChuKyDaKy: 1,
                        tongSoChuKy: tongSoKy,
                        fileName: nameFileTs,
                        keyKcb: {
                            noiTru: keyKcb.noiTru,
                            maBenhNhan: keyKcb.maBenhNhan,
                            soVaoVien: keyKcb.soVaoVien,
                            soVaoVienDT: keyKcb.soVaoVienDT,
                            soBenhAn: keyKcb.soBenhAn,
                            sttDotDieuTri: keyKcb.sttDotDieuTri,
                            kyHieuPhieu: keyKcb.kyHieuPhieu,
                            idDieuTri: keyKcb.idDieuTri,
                            soPhieuDichVu: keyKcb.soPhieuDV,
                            ngay: keyKcb.ngay,
                            tuNgay: keyKcb.tuNgay,
                            denNgay: keyKcb.denNgay,
                            maKhoa: keyKcb.maKhoa,
                            tenKhoa: keyKcb.tenKhoa,
                            nghiepVu: keyKcb.nghiepVuToaThuoc,
                            toaThuoc: keyKcb.toa,
                            soBe: keyKcb.babyNumber,
                            maDichVu: keyKcb.maDichVu,
                            inTong: keyKcb.inTong,
                            kyHieuPhieuCha: keyKcb.kyHieuPhieuCha,
                            isPhieuCon: keyKcb.isPhieuCon
                        },
                        signXML: {
                            ...objSignXmlApi,
                            nameFile: nameFileTs,
                            keyminio: keyMinioApi,
                            base64XmlSigned: '',
                            tagSaveSignature: role.key,
                            tagSigning: tagRefMap[role.key],
                            referenceId: tagRefMap[role.key],
                            signed: statusFileSignedApi
                        }
                    };

                    log(`⚡ [SmartCA API] Gửi ký số «${role.label}» (${urlSignHash})...`);
                    setStatus(`Ký API «${role.label}»...`);
                    let signRes = await $.ajax({
                        type: 'POST',
                        contentType: 'application/json',
                        dataType: 'json',
                        url: urlSignHash,
                        data: JSON.stringify(signPayload),
                        timeout: Math.max(CFG.kysoWaitMs || 60000, 90000)
                    });
                    if (typeof signRes === 'string') {
                        try { signRes = JSON.parse(signRes); } catch (e) { }
                    }

                    if (signRes && Number(signRes.SUCCESS) > 0 && signRes.DOCTYPE === 'XML' && signRes.KEYMINIO) {
                        if (role.key === 'CKS_BENH_VIEN') {
                            await Promise.resolve($.post('api/kham-suc-khoe/qd-2062/tiep-nhan', {
                                maBenhNhan: bnMa,
                                soVaoVien: bnSvv,
                                iD: '0',
                                loaiKSK: 'TU_18_TUOI_TRO_LEN',
                                keyMinIO: signRes.KEYMINIO,
                                dvtt: dvttVal
                            })).catch(() => null);
                        }
                        await Promise.resolve($.ajax({
                            type: 'GET',
                            dataType: 'json',
                            url: 'smartca-delete-phieu-lock?' + $.param({ ...lockParams, keySign })
                        })).catch(() => null);

                        markKyso(mayte, role.key);
                        success(`✓ ⚡ [SmartCA API] Hoàn tất ký «${role.label}»!`);
                    } else {
                        const msg = (signRes && (signRes.MESSAGE || signRes.message)) || 'Không rõ lỗi';
                        warn(`[SmartCA API] Ký «${role.label}» thất bại: ${msg} — Chuyển sang UI Mode`);
                        return false;
                    }
                }

                success(`✓ ⚡ [SmartCA API] Đã hoàn tất ký số siêu tốc cho BN ${bnMa}`);
                return true;
            } catch (err) {
                if (isSmartCALoginAppeared()) {
                    onSmartCaLoginDetected();
                    return 'LOGIN_DETECTED';
                }
                const errMsg = (err && (err.responseJSON && err.responseJSON.message)) || (err && err.statusText) || (err && err.message) || String(err);
                warn(`[SmartCA API] Lỗi (${errMsg}) — Tự động chuyển sang UI Mode`);
                return false;
            }
        }

        async function kySoViaFloat() {
            if (!CFG.enableKySo) {
                log('Ký số SmartCA đang TẮT trong cấu hình, bỏ qua bước ký');
                return;
            }
            if (isSmartCALoginAppeared()) {
                onSmartCaLoginDetected();
                return 'LOGIN_DETECTED';
            }
            if (!dangNhapLieu()) {
                warn('Không ở trạng thái khám/sửa — Bỏ qua ký số');
                return;
            }

            const mayte = bnMayte();
            if (kysoDu2(mayte)) {
                log(`BN ${mayte} đã có đủ 2 chữ ký số — Bỏ qua ký`);
                return;
            }

            log(`===== BẮT ĐẦU KÝ SỐ SMARTCA BN ${mayte} =====`);
            closeKskDialog();
            await sleep(150);

            if (isSmartCALoginAppeared()) {
                onSmartCaLoginDetected();
                return 'LOGIN_DETECTED';
            }

            if (!(await openSmartCaFloat())) {
                if (isSmartCALoginAppeared()) return 'LOGIN_DETECTED';
                return;
            }
            if (isSmartCALoginAppeared()) {
                onSmartCaLoginDetected();
                return 'LOGIN_DETECTED';
            }

            if (!(await goTabKhac(5000))) {
                closeSmartCaModal();
                return;
            }

            const $signBtn = await waitKskSignBtn(CFG.kysoGridWaitMs);
            if (!$signBtn) {
                if (isSmartCALoginAppeared()) {
                    onSmartCaLoginDetected();
                    return 'LOGIN_DETECTED';
                }
                warn('Không tìm thấy nút ký XML KSK trong bảng — Đóng SmartCA');
                closeSmartCaModal();
                return;
            }

            // Ký vai trò 1
            if (!kysoDaKy(mayte, CFG.vaiTro1)) {
                const ret1 = await kyMotVaiTro(CFG.vaiTro1, 'Người kết luận');
                if (ret1 === 'LOGIN_DETECTED') {
                    return 'LOGIN_DETECTED';
                }
                if (!ret1) {
                    closeSmartCaModal();
                    return;
                }
            }

            if (STOP) {
                closeSmartCaModal();
                return;
            }

            // Ký vai trò 2
            if (!kysoDaKy(mayte, CFG.vaiTro2)) {
                await sleep(200);
                await goTabKhac(4000);
                await waitKskSignBtn(CFG.kysoGridWaitMs);
                const ret2 = await kyMotVaiTro(CFG.vaiTro2, 'Chữ ký bệnh viện');
                if (ret2 === 'LOGIN_DETECTED') {
                    return 'LOGIN_DETECTED';
                }
            }

            await sleep(200);
            closeSmartCaModal();
            success(`Đã hoàn tất ký số SmartCA cho BN ${mayte}`);
        }

        // =========================================================================
        // 8. TIẾN TRÌNH XỬ LÝ TỪNG BỆNH NHÂN (PATIENT PROCESSING PIPELINE)
        // =========================================================================
        async function fillCurrentPatient(id) {
            if (STOP) return;
            const m0 = mayteOfRow(id);
            if (m0 && BN_DONE.has(m0)) {
                log(`⏭ Bệnh nhân ${m0} đã được xử lý trước đó — Bỏ qua`);
                DONE.add(String(id));
                updateCount();
                return;
            }

            log(`==================== XỬ LÝ BN #${id} ${m0 ? `(Mã: ${m0})` : ''} ====================`);

            if (!(await ensureExamOpen())) {
                warn('Không thể mở màn hình khám cho bệnh nhân này');
                return;
            }

            const mayte = bnMayte() || m0;
            if (mayte && BN_DONE.has(mayte)) {
                log(`⏭ Bệnh nhân ${mayte} đã hoàn thành — Bỏ qua`);
                markBnDone(id);
                return;
            }

            const ageRaw = ($('#tuoi').val() || '').trim();
            if (!ageRaw) {
                warn('Thiếu thông tin tuổi bệnh nhân');
                return;
            }

            const age = parseInt(ageRaw, 10);
            if (isNaN(age)) return;

            const isNam = $('#gioitinh').val() === 'true';
            const isNu = !isNam;
            log(`Bệnh nhân: ${isNam ? 'Nam' : 'Nữ'}, ${age} tuổi`);

            if (age < 18) {
                warn('Bệnh nhân dưới 18 tuổi — Bỏ qua ca khám');
                await safeHuy();
                markBnDone(id);
                return;
            }

            // Kiểm tra BHYT
            try {
                await openBhyt();
            } catch (e) {
                await clickDongY(400);
            }

            // Điền sinh hiệu
            await guardReady('sinh hiệu');
            const v = generateVitals(age, isNam);
            fillSinhHieu(v);

            // Kiểm tra nút KSK đủ 18 tuổi
            const $btnKsk = $('#khamsuckhoetheodoituongdu18');
            if (!$btnKsk.is(':visible') || $btnKsk.prop('disabled')) {
                warn('Không thấy nút KSK đủ 18 tuổi (#khamsuckhoetheodoituongdu18)');
            } else {
                const kskRet = await fillKsk(age, v, isNu);
                if (kskRet === 'bad_cmnd') {
                    warn('CCCD không hợp lệ → Hủy ca này');
                    closeKskDialog();
                    await safeHuy();
                    markBnDone(id);
                    return;
                }

                if (kskRet) {
                    if (CFG.enableKySo) {
                        if (isSmartCALoginAppeared()) {
                            onSmartCaLoginDetected();
                        } else {
                            try {
                                let signRet = false;
                                if (CFG.apiMode) {
                                    signRet = await kySoViaApi();
                                }
                                if (signRet !== true && signRet !== 'LOGIN_DETECTED' && !STOP) {
                                    signRet = await kySoViaFloat();
                                }
                                if (signRet === 'LOGIN_DETECTED') {
                                    warn('Đã bỏ qua ký số cho BN này do phát hiện menu Đăng nhập SmartCA.');
                                }
                            } catch (e) {
                                warn(`Ký số SmartCA gặp lỗi: ${e && e.message}`);
                                closeSmartCaModal();
                            }
                        }
                    } else {
                        log('Phiếu KSK đã lưu — Ký số đang tắt');
                    }
                }
            }

            // Hủy & kết thúc ca khám
            await safeHuy();
            markBnDone(id);
            success(`Hoàn tất xuất sắc BN #${id} ${mayte ? `(${mayte})` : ''}`);
        }

        async function processRow(id) {
            if (STOP || DONE.has(String(id))) return;

            if (dangNhapLieu()) {
                const curId = $('#list1').jqGrid('getGridParam', 'selrow');
                if (curId && String(curId) !== String(id)) {
                    await safeHuy();
                } else if (curId && String(curId) === String(id)) {
                    await fillCurrentPatient(id);
                    return;
                }
            }

            await guardReady('chọn dòng');
            $('#list1').jqGrid('setSelection', id, true);
            await sleep(CFG.stepDelay);
            await waitIdle(4000, CFG.quietDelay);
            await fillCurrentPatient(id);
        }

        // =========================================================================
        // 9. ĐIỀU KHIỂN CHÍNH (MAIN LOOPS: START / STEP / PAUSE / STOP)
        // =========================================================================
        async function start() {
            if (RUNNING) {
                if (IS_PAUSED) {
                    IS_PAUSED = false;
                    updateUIButtons();
                    log('▶ Tiếp tục chạy tự động...');
                    return;
                }
                warn('Tiến trình đang chạy!');
                return;
            }

            RUNNING = true;
            STOP = false;
            IS_PAUSED = false;
            CONTINUOUS = true;
            REFRESH_REQUESTED = false;
            STEP = 0;
            updateUIButtons();
            log('🚀 BẮT ĐẦU VẬN HÀNH TỰ ĐỘNG LIÊN TỤC');
            updateCount();

            while (!STOP) {
                if (IS_PAUSED) {
                    await sleep(200);
                    continue;
                }

                try {
                    if (CFG.enableAutoRefresh || REFRESH_REQUESTED) {
                        REFRESH_REQUESTED = false;
                        await refreshList();
                    }

                    const ids = pendingIds();
                    if (!ids.length) {
                        const waitSec = (CFG.emptyWaitMs / 1000).toFixed(1);
                        log(`Danh sách trống — Chờ ${waitSec}s rồi làm mới lại danh sách...`);
                        updateCount();
                        await sleep(CFG.emptyWaitMs);
                        continue;
                    }

                    const id = pickRandomId();
                    if (!id) {
                        await sleep(CFG.emptyWaitMs);
                        continue;
                    }

                    await processRow(id);
                } catch (e) {
                    warn(`Lỗi trong vòng lặp chính: ${e && e.message}`);
                    console.error(e);
                    try {
                        await clickDongY(600);
                        await safeHuy();
                    } catch (e2) { }
                }

                await sleep(CFG.stepDelay);
            }

            log(`⏹ Tiến trình đã dừng — Đã xử lý ${COMPLETED_COUNT} ca khám.`);
            RUNNING = false;
            STOP = true;
            IS_PAUSED = false;
            CONTINUOUS = false;
            REFRESH_REQUESTED = false;
            updateUIButtons();
        }

        async function runOne() {
            if (RUNNING) {
                warn('Tiến trình đang chạy!');
                return;
            }

            RUNNING = true;
            STOP = false;
            IS_PAUSED = false;
            CONTINUOUS = false;
            REFRESH_REQUESTED = false;
            STEP = 0;
            updateUIButtons();
            log('▶ Thực hiện khám 1 ca đơn lẻ...');

            try {
                if (dangNhapLieu()) {
                    await fillCurrentPatient($('#list1').jqGrid('getGridParam', 'selrow'));
                } else {
                    const id = pickRandomId();
                    if (!id) warn('Không còn bệnh nhân trong danh sách');
                    else await processRow(id);
                }
            } catch (e) {
                warn(`Lỗi khám 1 ca: ${e && e.message}`);
            }

            RUNNING = false;
            STOP = true;
            IS_PAUSED = false;
            CONTINUOUS = false;
            REFRESH_REQUESTED = false;
            updateUIButtons();
            log('Hoàn thành 1 ca khám.');
        }

        function pause() {
            if (!RUNNING) return;
            IS_PAUSED = !IS_PAUSED;
            log(IS_PAUSED ? '⏸ TẠM DỪNG TIẾN TRÌNH' : '▶ TIẾP TỤC TIẾN TRÌNH');
            updateUIButtons();
        }

        function stop() {
            STOP = true;
            IS_PAUSED = false;
            REFRESH_REQUESTED = false;
            log('⏹ ĐANG DỪNG TIẾN TRÌNH...');
            updateUIButtons();
        }

        function resetAll() {
            DONE.clear();
            BN_DONE.clear();
            for (const k in KYSO_DONE) delete KYSO_DONE[k];
            STEP = 0;
            COMPLETED_COUNT = 0;
            updateCount();
            setStatus('Đã đặt lại dữ liệu bộ nhớ tạm về 0');
            log('🧹 Đã reset danh sách đã khám & số lượng hoàn thành về 0.');
        }

        // =========================================================================
        // 10. GIAO DIỆN ĐIỀU KHIỂN & CẤU HÌNH TRỰC QUAN (FLOATING UI PANEL)
        // =========================================================================
        function updateUIButtons() {
            const btnGo = document.getElementById('ksk_btn_start');
            const btnPause = document.getElementById('ksk_btn_pause');
            const btnStop = document.getElementById('ksk_btn_stop');
            const btnOne = document.getElementById('ksk_btn_one');
            const btnRefresh = document.getElementById('ksk_btn_refresh');

            if (btnGo) btnGo.disabled = RUNNING;
            if (btnPause) {
                btnPause.disabled = !RUNNING;
                btnPause.textContent = IS_PAUSED ? '▶ Tiếp tục' : '⏸ Tạm dừng';
            }
            if (btnStop) btnStop.disabled = !RUNNING;
            if (btnOne) btnOne.disabled = RUNNING;
            if (btnRefresh) btnRefresh.disabled = RUNNING && !IS_PAUSED;
        }

        function mountUI() {
            $('#ksk_pro_panel').remove();
            $('#ksk_pro_style').remove();

            const css = `
                #ksk_pro_panel {
                    position: fixed;
                    top: 65px;
                    right: 15px;
                    z-index: 9999999;
                    width: 450px;
                    background: #111827;
                    color: #f3f4f6;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 12px;
                    border-radius: 12px;
                    box-shadow: 0 16px 36px rgba(0,0,0,0.5), 0 0 1px rgba(255,255,255,0.15);
                    border: 1px solid #374151;
                    overflow: hidden;
                    box-sizing: border-box;
                }
                #ksk_pro_header {
                    background: linear-gradient(135deg, #1e3a8a, #0284c7);
                    padding: 10px 14px;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    cursor: move;
                    user-select: none;
                    border-bottom: 1px solid #1e40af;
                }
                #ksk_pro_header .title {
                    font-weight: 700;
                    font-size: 13px;
                    color: #ffffff;
                    display: flex;
                    align-items: center;
                    gap: 6px;
                }
                #ksk_pro_header .badge {
                    font-size: 10px;
                    background: rgba(255,255,255,0.25);
                    padding: 2px 6px;
                    border-radius: 6px;
                    font-weight: 600;
                }
                .ksk-hbtn {
                    background: transparent;
                    border: 0;
                    color: #e0f2fe;
                    cursor: pointer;
                    font-size: 14px;
                    padding: 2px 6px;
                    border-radius: 4px;
                }
                .ksk-hbtn:hover { background: rgba(255,255,255,0.2); color: #fff; }

                #ksk_pro_body {
                    padding: 12px;
                    max-height: 82vh;
                    overflow-y: auto;
                    box-sizing: border-box;
                }
                /* Controls bar */
                .ksk-actions {
                    display: grid;
                    grid-template-columns: 1.5fr 1fr 1fr 1fr;
                    gap: 6px;
                    margin-bottom: 10px;
                }
                .ksk-btn {
                    padding: 8px 10px;
                    border: 0;
                    border-radius: 6px;
                    font-weight: 700;
                    font-size: 11px;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 4px;
                    transition: all 0.15s;
                }
                .ksk-btn:disabled { opacity: 0.45; cursor: not-allowed; }
                .ksk-btn-start { background: #10b981; color: #022c22; }
                .ksk-btn-start:hover:not(:disabled) { background: #059669; color: #fff; }
                .ksk-btn-pause { background: #f59e0b; color: #451a03; }
                .ksk-btn-pause:hover:not(:disabled) { background: #d97706; color: #fff; }
                .ksk-btn-stop { background: #ef4444; color: #450a0a; }
                .ksk-btn-stop:hover:not(:disabled) { background: #dc2626; color: #fff; }
                .ksk-btn-step { background: #0ea5e9; color: #082f49; }
                .ksk-btn-step:hover:not(:disabled) { background: #0284c7; color: #fff; }

                /* Stats card */
                .ksk-stats-card {
                    background: #1f2937;
                    border: 1px solid #374151;
                    border-radius: 8px;
                    padding: 8px 12px;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    margin-bottom: 10px;
                }
                .ksk-stat-item {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                }
                .ksk-stat-val { font-size: 16px; font-weight: 800; color: #38bdf8; }
                .ksk-stat-val.done { color: #34d399; }
                .ksk-stat-lbl { font-size: 10px; color: #9ca3af; text-transform: uppercase; }

                /* Quick toggles bar */
                .ksk-toggles-bar {
                    display: flex;
                    gap: 6px;
                    margin-bottom: 10px;
                    flex-wrap: wrap;
                }
                .ksk-chip {
                    flex: 1;
                    min-width: 90px;
                    padding: 5px 8px;
                    border-radius: 6px;
                    background: #1f2937;
                    border: 1px solid #374151;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    cursor: pointer;
                    font-size: 11px;
                    user-select: none;
                }
                .ksk-chip.active { background: #064e3b; border-color: #10b981; color: #a7f3d0; }
                .ksk-chip.editing { background: #7c2d12; border-color: #f97316; color: #fed7aa; }

                /* Status box */
                #ksk_auto_status {
                    padding: 6px 10px;
                    background: #1e293b;
                    border-radius: 6px;
                    color: #fbbf24;
                    font-weight: 500;
                    margin-bottom: 10px;
                    font-size: 11px;
                    min-height: 20px;
                    border-left: 3px solid #f59e0b;
                    word-break: break-word;
                }

                /* Nav Tabs */
                .ksk-tabs {
                    display: flex;
                    border-bottom: 1px solid #374151;
                    margin-bottom: 10px;
                    gap: 2px;
                }
                .ksk-tab-btn {
                    padding: 6px 10px;
                    background: transparent;
                    border: 0;
                    color: #9ca3af;
                    font-weight: 600;
                    font-size: 11px;
                    cursor: pointer;
                    border-bottom: 2px solid transparent;
                }
                .ksk-tab-btn.active {
                    color: #38bdf8;
                    border-bottom-color: #38bdf8;
                }

                /* Tab contents */
                .ksk-tab-panel { display: none; }
                .ksk-tab-panel.active { display: block; }

                .ksk-row {
                    display: grid;
                    grid-template-columns: 140px 1fr;
                    gap: 8px;
                    align-items: center;
                    margin-bottom: 6px;
                }
                .ksk-lbl { color: #9ca3af; font-size: 11px; }
                .ksk-input {
                    background: #1f2937;
                    border: 1px solid #4b5563;
                    border-radius: 4px;
                    padding: 4px 6px;
                    color: #f3f4f6;
                    font-size: 11px;
                    width: 100%;
                    box-sizing: border-box;
                }
                .ksk-input:focus { border-color: #38bdf8; outline: none; }
                .ksk-split-2 {
                    display: grid;
                    grid-template-columns: 1fr 1fr;
                    gap: 6px;
                }

                /* Log box */
                #ksk_auto_log {
                    height: 120px;
                    overflow-y: auto;
                    background: #030712;
                    border: 1px solid #1f2937;
                    border-radius: 6px;
                    padding: 6px;
                    font-family: Consolas, monospace;
                    font-size: 10.5px;
                    line-height: 1.35;
                    margin-top: 10px;
                }
                .ksk-log-line { margin-bottom: 2px; word-break: break-all; }
                .ksk-log-info { color: #94a3b8; }
                .ksk-log-success { color: #34d399; font-weight: 600; }
                .ksk-log-warn { color: #fbbf24; }
                .ksk-log-error { color: #f87171; }

                /* Footer Config Buttons */
                .ksk-cfg-footer {
                    display: flex;
                    gap: 6px;
                    margin-top: 8px;
                }
            `;

            $('<style id="ksk_pro_style">').text(css).appendTo('head');

            const html = `
                <div id="ksk_pro_panel">
                    <div id="ksk_pro_header">
                        <div class="title">
                            <span>⚡ KSK & SmartCA Pro</span>
                            <span class="badge">v4.0</span>
                        </div>
                        <div style="display:flex; gap:4px;">
                            <button type="button" class="ksk-hbtn" id="ksk_btn_min" title="Thu nhỏ/Mở rộng">_</button>
                            <button type="button" class="ksk-hbtn" id="ksk_btn_close" title="Đóng panel">✕</button>
                        </div>
                    </div>

                    <div id="ksk_pro_body">
                        <!-- Controls -->
                        <div class="ksk-actions">
                            <button type="button" class="ksk-btn ksk-btn-start" id="ksk_btn_start">▶ BẮT ĐẦU</button>
                            <button type="button" class="ksk-btn ksk-btn-pause" id="ksk_btn_pause" disabled>⏸ Tạm dừng</button>
                            <button type="button" class="ksk-btn ksk-btn-stop" id="ksk_btn_stop" disabled>⏹ Dừng</button>
                            <button type="button" class="ksk-btn ksk-btn-step" id="ksk_btn_one">⏭ 1 Ca</button>
                        </div>

                        <!-- Stats -->
                        <div class="ksk-stats-card">
                            <div class="ksk-stat-item">
                                <span class="ksk-stat-val" id="ksk_stat_total">0</span>
                                <span class="ksk-stat-lbl">Trên lưới</span>
                            </div>
                            <div class="ksk-stat-item">
                                <span class="ksk-stat-val done" id="ksk_stat_done">0</span>
                                <span class="ksk-stat-lbl">Hoàn thành</span>
                            </div>
                            <div class="ksk-stat-item">
                                <span class="ksk-stat-val" id="ksk_stat_pending">0</span>
                                <span class="ksk-stat-lbl">Còn lại</span>
                            </div>
                            <div style="display: flex; gap: 4px;">
                                <button type="button" class="ksk-btn" id="ksk_btn_refresh" style="background:#0284c7;color:#fff;padding:4px 8px;" title="Làm mới danh sách #lammoi">⟳ Nạp DS</button>
                                <button type="button" class="ksk-btn" id="ksk_btn_reset" style="background:#4b5563;color:#fff;padding:4px 8px;" title="Xóa danh sách tạm và bộ đếm">🧹 Reset</button>
                            </div>
                        </div>

                        <!-- Quick Toggles -->
                        <div class="ksk-toggles-bar">
                            <div class="ksk-chip ${CFG.examMode === 'dang_kham' ? 'editing' : 'active'}" id="ksk_chip_exam_mode" title="Nhấn để đổi chế độ">
                                <span>Chế độ:</span>
                                <strong>${CFG.examMode === 'dang_kham' ? '✏️ Đang khám (#sua)' : '🩺 Chờ khám (#kham)'}</strong>
                            </div>
                            <div class="ksk-chip ${CFG.enableKySo ? 'active' : ''}" id="ksk_chip_kyso" title="Nhấn để bật/tắt ký số">
                                <span>Ký số:</span>
                                <strong>${CFG.enableKySo ? '🔐 BẬT' : '🔓 TẮT'}</strong>
                            </div>
                            <div class="ksk-chip ${CFG.enableAutoRefresh ? 'active' : ''}" id="ksk_chip_refresh" title="Nhấn để bật/tắt tự làm mới">
                                <span>Tự làm mới:</span>
                                <strong>${CFG.enableAutoRefresh ? '⟳ BẬT' : '⏸ TẮT'}</strong>
                            </div>
                        </div>

                        <!-- Status bar -->
                        <div id="ksk_auto_status">Sẵn sàng vận hành</div>

                        <!-- Tabs Header -->
                        <div class="ksk-tabs">
                            <button type="button" class="ksk-tab-btn active" data-tab="tab_vitals">🩺 Sinh hiệu</button>
                            <button type="button" class="ksk-tab-btn" data-tab="tab_ksk">📝 Bác sĩ & KSK</button>
                            <button type="button" class="ksk-tab-btn" data-tab="tab_delays">⏱️ Tốc độ & Delays</button>
                            <button type="button" class="ksk-tab-btn" data-tab="tab_opts">⚙️ Ký số & Khác</button>
                        </div>

                        <!-- Tab 1: Sinh hiệu (Vitals) -->
                        <div class="ksk-tab-panel active" id="tab_vitals">
                            <div class="ksk-row">
                                <span class="ksk-lbl">Cao Nam (&lt;60t / ≥60t):</span>
                                <div class="ksk-split-2">
                                    <input type="text" class="ksk-input" id="cfg_nam_h" value="${CFG.namHeightMin}-${CFG.namHeightMax}" title="Min-Max chiều cao nam trẻ (cm)">
                                    <input type="text" class="ksk-input" id="cfg_nam_h60" value="${CFG.namHeight60Min}-${CFG.namHeight60Max}" title="Min-Max chiều cao nam ≥60 tuổi (cm)">
                                </div>
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Cao Nữ (&lt;60t / ≥60t):</span>
                                <div class="ksk-split-2">
                                    <input type="text" class="ksk-input" id="cfg_nu_h" value="${CFG.nuHeightMin}-${CFG.nuHeightMax}" title="Min-Max chiều cao nữ trẻ (cm)">
                                    <input type="text" class="ksk-input" id="cfg_nu_h60" value="${CFG.nuHeight60Min}-${CFG.nuHeight60Max}" title="Min-Max chiều cao nữ ≥60 tuổi (cm)">
                                </div>
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Chỉ số BMI (Min-Max):</span>
                                <div class="ksk-split-2">
                                    <input type="number" step="0.1" class="ksk-input" id="cfg_bmi_min" value="${CFG.bmiMin}">
                                    <input type="number" step="0.1" class="ksk-input" id="cfg_bmi_max" value="${CFG.bmiMax}">
                                </div>
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Huyết áp trên (Trẻ / ≥60t):</span>
                                <div class="ksk-split-2">
                                    <input type="text" class="ksk-input" id="cfg_ha" value="${CFG.haMin}-${CFG.haMax}" title="HA trên người trẻ">
                                    <input type="text" class="ksk-input" id="cfg_ha60" value="${CFG.ha60Min}-${CFG.ha60Max}" title="HA trên ≥60t">
                                </div>
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Mạch (Trẻ / ≥60t):</span>
                                <div class="ksk-split-2">
                                    <input type="text" class="ksk-input" id="cfg_mach" value="${CFG.machMin}-${CFG.machMax}">
                                    <input type="text" class="ksk-input" id="cfg_mach60" value="${CFG.mach60Min}-${CFG.mach60Max}">
                                </div>
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Nhịp thở / Nhiệt độ:</span>
                                <div class="ksk-split-2">
                                    <input type="text" class="ksk-input" id="cfg_nhiptho" value="${CFG.nhipThoMin}-${CFG.nhipThoMax}" title="Nhịp thở Min-Max">
                                    <input type="number" step="0.1" class="ksk-input" id="cfg_nhietdo" value="${CFG.nhietDo}" title="Nhiệt độ °C">
                                </div>
                            </div>
                        </div>

                        <!-- Tab 2: Bác sĩ & Nội dung KSK -->
                        <div class="ksk-tab-panel" id="tab_ksk">
                            <div class="ksk-row">
                                <span class="ksk-lbl">Mã & Tên Bác sĩ:</span>
                                <div class="ksk-split-2">
                                    <input type="text" class="ksk-input" id="cfg_ma_bs" value="${CFG.maBacSi}" placeholder="Mã BS">
                                    <input type="text" class="ksk-input" id="cfg_ten_bs" value="${CFG.tenBacSi}" placeholder="Tên BS">
                                </div>
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Lý do khám KSK:</span>
                                <input type="text" class="ksk-input" id="cfg_lydo" value="${CFG.lyDoKham}">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Nội dung Tuần hoàn:</span>
                                <input type="text" class="ksk-input" id="cfg_tuanhoan" value="${CFG.noiDungTuanHoan}">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Lâm sàng các khoa khác:</span>
                                <input type="text" class="ksk-input" id="cfg_lamsang" value="${CFG.noiDungLamSang}">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Địa chỉ bổ sung:</span>
                                <input type="text" class="ksk-input" id="cfg_diachi" value="${CFG.diaChiThem}">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Mắt / Tai / Răng:</span>
                                <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:4px;">
                                    <input type="text" class="ksk-input" id="cfg_thiluc" value="${CFG.chiSoThiLuc}" title="Thị lực">
                                    <input type="text" class="ksk-input" id="cfg_taithuong" value="${CFG.chiSoTaiThuong}" title="Tai nói thường">
                                    <input type="text" class="ksk-input" id="cfg_taitham" value="${CFG.chiSoTaiTham}" title="Tai nói thầm">
                                </div>
                            </div>
                        </div>

                        <!-- Tab 3: Tốc độ & Delays -->
                        <div class="ksk-tab-panel" id="tab_delays">
                            <div class="ksk-row">
                                <span class="ksk-lbl">Delay thao tác (stepDelay):</span>
                                <input type="number" class="ksk-input" id="cfg_step_delay" value="${CFG.stepDelay}" min="20" max="1000" step="10">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Chờ UI ổn định (quietDelay):</span>
                                <input type="number" class="ksk-input" id="cfg_quiet_delay" value="${CFG.quietDelay}" min="50" max="1000" step="20">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Chu kỳ polling (pollInterval):</span>
                                <input type="number" class="ksk-input" id="cfg_poll_interval" value="${CFG.pollInterval}" min="20" max="300" step="10">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Chờ khi list trống (ms):</span>
                                <input type="number" class="ksk-input" id="cfg_empty_wait" value="${CFG.emptyWaitMs}" min="500" max="30000" step="500">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Timeout mở phiếu KSK (ms):</span>
                                <input type="number" class="ksk-input" id="cfg_ksk_timeout" value="${CFG.kskLoadTimeout}" min="3000" max="30000" step="1000">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Timeout SmartCA App (ms):</span>
                                <input type="number" class="ksk-input" id="cfg_kyso_timeout" value="${CFG.kysoWaitMs}" min="10000" max="120000" step="5000">
                            </div>
                        </div>

                        <!-- Tab 4: Ký số & Tùy chọn khác -->
                        <div class="ksk-tab-panel" id="tab_opts">
                            <div class="ksk-row">
                                <span class="ksk-lbl">Vai trò 1 (Người kết luận):</span>
                                <input type="text" class="ksk-input" id="cfg_vaitro1" value="${CFG.vaiTro1}">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Vai trò 2 (Bệnh viện):</span>
                                <input type="text" class="ksk-input" id="cfg_vaitro2" value="${CFG.vaiTro2}">
                            </div>
                            <div class="ksk-row">
                                <span class="ksk-lbl">Mốc tuổi phân loại:</span>
                                <div class="ksk-split-2">
                                    <input type="number" class="ksk-input" id="cfg_tuoi_sv" value="${CFG.tuoiSinhVienMax}" title="Tuổi HSSV tối đa">
                                    <input type="text" class="ksk-input" id="cfg_dt_ld" value="${CFG.dtNguoiLaoDong}" title="Mã đối tượng lao động (13)">
                                </div>
                            </div>
                            <div style="margin-top:6px; display:flex; flex-direction:column; gap:4px;">
                                <label style="display:flex;align-items:center;gap:6px;cursor:pointer;">
                                    <input type="checkbox" id="cfg_login_detect" ${CFG.autoDisableOnLoginAlert ? 'checked' : ''}> Tự động phát hiện & tắt ký số khi có bảng "Đăng nhập SmartCA"
                                </label>
                                <label style="display:flex;align-items:center;gap:6px;cursor:pointer;">
                                    <input type="checkbox" id="cfg_check_bhyt" ${CFG.enableCheckBhyt ? 'checked' : ''}> Tự động kiểm tra BHYT (#kt_tt_thebhyt)
                                </label>
                                <label style="display:flex;align-items:center;gap:6px;cursor:pointer;">
                                    <input type="checkbox" id="cfg_fix_cccd" ${CFG.autoFixCccd ? 'checked' : ''}> Tự thêm 0 vào đầu CCCD 11 số
                                </label>
                                <label style="display:flex;align-items:center;gap:6px;cursor:pointer;">
                                    <input type="checkbox" id="cfg_skip_cccd" ${CFG.skipInvalidCccd ? 'checked' : ''}> Bỏ qua ca khám nếu CCCD không đủ 12 số
                                </label>
                                <label style="display:flex;align-items:center;gap:6px;cursor:pointer;">
                                    <input type="checkbox" id="cfg_api_mode" ${CFG.apiMode ? 'checked' : ''}> ⚡ API Mode Siêu Tốc (Lưu thẳng API, tự fallback UI nếu lỗi)
                                </label>
                            </div>
                        </div>

                        <!-- Config Save/Reset Buttons -->
                        <div class="ksk-cfg-footer">
                            <button type="button" class="ksk-btn" id="ksk_btn_save_cfg" style="background:#10b981;color:#fff;flex:2;">💾 Lưu & Áp dụng cấu hình</button>
                            <button type="button" class="ksk-btn" id="ksk_btn_reset_cfg" style="background:#374151;color:#e5e7eb;flex:1;">↺ Mặc định</button>
                        </div>

                        <!-- Logs box -->
                        <div id="ksk_auto_log"></div>
                    </div>
                </div>
            `;

            $('body').append(html);
            setupUIEvents();
            setupDraggable();
            updateCount();
            updateUIButtons();
            log('Panel giao diện KSK Auto Pro v4.0 đã sẵn sàng.');
        }

        // =========================================================================
        // 11. XỬ LÝ SỰ KIỆN GIAO DIỆN (UI EVENT LISTENERS & CONFIG BINDING)
        // =========================================================================
        function parseRange(str, defMin, defMax) {
            if (!str) return { min: defMin, max: defMax };
            const parts = str.split('-').map(s => parseInt(s.trim(), 10));
            if (parts.length >= 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                return { min: Math.min(parts[0], parts[1]), max: Math.max(parts[0], parts[1]) };
            }
            if (parts.length === 1 && !isNaN(parts[0])) {
                return { min: parts[0], max: parts[0] };
            }
            return { min: defMin, max: defMax };
        }

        function applyConfigFromUI() {
            // Tab 1: Sinh hiệu
            const namH = parseRange($('#cfg_nam_h').val(), CFG.namHeightMin, CFG.namHeightMax);
            CFG.namHeightMin = namH.min;
            CFG.namHeightMax = namH.max;

            const namH60 = parseRange($('#cfg_nam_h60').val(), CFG.namHeight60Min, CFG.namHeight60Max);
            CFG.namHeight60Min = namH60.min;
            CFG.namHeight60Max = namH60.max;

            const nuH = parseRange($('#cfg_nu_h').val(), CFG.nuHeightMin, CFG.nuHeightMax);
            CFG.nuHeightMin = nuH.min;
            CFG.nuHeightMax = nuH.max;

            const nuH60 = parseRange($('#cfg_nu_h60').val(), CFG.nuHeight60Min, CFG.nuHeight60Max);
            CFG.nuHeight60Min = nuH60.min;
            CFG.nuHeight60Max = nuH60.max;

            CFG.bmiMin = parseFloat($('#cfg_bmi_min').val()) || CFG.bmiMin;
            CFG.bmiMax = parseFloat($('#cfg_bmi_max').val()) || CFG.bmiMax;

            const ha = parseRange($('#cfg_ha').val(), CFG.haMin, CFG.haMax);
            CFG.haMin = ha.min;
            CFG.haMax = ha.max;

            const ha60 = parseRange($('#cfg_ha60').val(), CFG.ha60Min, CFG.ha60Max);
            CFG.ha60Min = ha60.min;
            CFG.ha60Max = ha60.max;

            const mach = parseRange($('#cfg_mach').val(), CFG.machMin, CFG.machMax);
            CFG.machMin = mach.min;
            CFG.machMax = mach.max;

            const mach60 = parseRange($('#cfg_mach60').val(), CFG.mach60Min, CFG.mach60Max);
            CFG.mach60Min = mach60.min;
            CFG.mach60Max = mach60.max;

            const nhip = parseRange($('#cfg_nhiptho').val(), CFG.nhipThoMin, CFG.nhipThoMax);
            CFG.nhipThoMin = nhip.min;
            CFG.nhipThoMax = nhip.max;

            CFG.nhietDo = parseFloat($('#cfg_nhietdo').val()) || CFG.nhietDo;

            // Tab 2: Bác sĩ & KSK
            CFG.maBacSi = ($('#cfg_ma_bs').val() || '').trim() || CFG.maBacSi;
            CFG.tenBacSi = ($('#cfg_ten_bs').val() || '').trim() || CFG.tenBacSi;
            CFG.lyDoKham = ($('#cfg_lydo').val() || '').trim() || CFG.lyDoKham;
            CFG.noiDungTuanHoan = ($('#cfg_tuanhoan').val() || '').trim() || CFG.noiDungTuanHoan;
            CFG.noiDungLamSang = ($('#cfg_lamsang').val() || '').trim() || CFG.noiDungLamSang;
            CFG.diaChiThem = ($('#cfg_diachi').val() || '').trim() || CFG.diaChiThem;
            CFG.chiSoThiLuc = ($('#cfg_thiluc').val() || '').trim() || CFG.chiSoThiLuc;
            CFG.chiSoTaiThuong = ($('#cfg_taithuong').val() || '').trim() || CFG.chiSoTaiThuong;
            CFG.chiSoTaiTham = ($('#cfg_taitham').val() || '').trim() || CFG.chiSoTaiTham;

            // Tab 3: Delays
            CFG.stepDelay = parseInt($('#cfg_step_delay').val(), 10) || CFG.stepDelay;
            CFG.quietDelay = parseInt($('#cfg_quiet_delay').val(), 10) || CFG.quietDelay;
            CFG.pollInterval = parseInt($('#cfg_poll_interval').val(), 10) || CFG.pollInterval;
            CFG.emptyWaitMs = parseInt($('#cfg_empty_wait').val(), 10) || CFG.emptyWaitMs;
            CFG.kskLoadTimeout = parseInt($('#cfg_ksk_timeout').val(), 10) || CFG.kskLoadTimeout;
            CFG.kysoWaitMs = parseInt($('#cfg_kyso_timeout').val(), 10) || CFG.kysoWaitMs;

            // Tab 4: Tùy chọn & Ký số
            CFG.vaiTro1 = ($('#cfg_vaitro1').val() || '').trim() || CFG.vaiTro1;
            CFG.vaiTro2 = ($('#cfg_vaitro2').val() || '').trim() || CFG.vaiTro2;
            CFG.tuoiSinhVienMax = parseInt($('#cfg_tuoi_sv').val(), 10) || CFG.tuoiSinhVienMax;
            CFG.dtNguoiLaoDong = ($('#cfg_dt_ld').val() || '').trim() || CFG.dtNguoiLaoDong;
            CFG.enableCheckBhyt = $('#cfg_check_bhyt').is(':checked');
            CFG.autoDisableOnLoginAlert = $('#cfg_login_detect').is(':checked');
            CFG.autoFixCccd = $('#cfg_fix_cccd').is(':checked');
            CFG.skipInvalidCccd = $('#cfg_skip_cccd').is(':checked');
            CFG.apiMode = $('#cfg_api_mode').is(':checked');

            saveConfigToStorage();
            success('Đã lưu và áp dụng cấu hình mới vào hệ thống!');
        }

        function setupUIEvents() {
            // Main control buttons
            $('#ksk_btn_start').on('click', start);
            $('#ksk_btn_pause').on('click', pause);
            $('#ksk_btn_stop').on('click', stop);
            $('#ksk_btn_one').on('click', runOne);

            $('#ksk_btn_refresh').on('click', async function () {
                if (RUNNING && !IS_PAUSED) {
                    REFRESH_REQUESTED = true;
                    log('Đã gửi yêu cầu làm mới — Sẽ nạp danh sách sau ca hiện tại.');
                    return;
                }
                $(this).prop('disabled', true);
                await refreshList();
                $(this).prop('disabled', false);
            });

            $('#ksk_btn_reset').on('click', resetAll);

            // Quick chips
            $('#ksk_chip_exam_mode').on('click', function () {
                CFG.examMode = CFG.examMode === 'dang_kham' ? 'cho_kham' : 'dang_kham';
                const isDangKham = CFG.examMode === 'dang_kham';
                $(this).toggleClass('editing', isDangKham).toggleClass('active', !isDangKham);
                $(this).find('strong').text(isDangKham ? '✏️ Đang khám (#sua)' : '🩺 Chờ khám (#kham)');
                log(`Chuyển sang chế độ: ${isDangKham ? 'ĐANG KHÁM (ấn Sửa #sua)' : 'CHỜ KHÁM (ấn Khám #kham)'}`);
                saveConfigToStorage();
            });

            $('#ksk_chip_kyso').on('click', function () {
                CFG.enableKySo = !CFG.enableKySo;
                $(this).toggleClass('active', CFG.enableKySo);
                $(this).find('strong').text(CFG.enableKySo ? '🔐 BẬT' : '🔓 TẮT');
                log(`Ký số SmartCA: ${CFG.enableKySo ? 'BẬT' : 'TẮT'}`);
                saveConfigToStorage();
            });

            $('#ksk_chip_refresh').on('click', function () {
                CFG.enableAutoRefresh = !CFG.enableAutoRefresh;
                $(this).toggleClass('active', CFG.enableAutoRefresh);
                $(this).find('strong').text(CFG.enableAutoRefresh ? '⟳ BẬT' : '⏸ TẮT');
                log(`Tự động làm mới danh sách: ${CFG.enableAutoRefresh ? 'BẬT' : 'TẮT'}`);
                saveConfigToStorage();
            });

            // Tabs navigation
            $('.ksk-tab-btn').on('click', function () {
                $('.ksk-tab-btn').removeClass('active');
                $('.ksk-tab-panel').removeClass('active');

                $(this).addClass('active');
                const targetId = $(this).attr('data-tab');
                $('#' + targetId).addClass('active');
            });

            // Config footer buttons
            $('#ksk_btn_save_cfg').on('click', function () {
                applyConfigFromUI();
                const $btn = $(this);
                const originalText = $btn.text();
                $btn.text('✓ Đã lưu thành công!').css('background', '#059669');
                setTimeout(() => {
                    $btn.text(originalText).css('background', '#10b981');
                }, 1500);
            });

            $('#ksk_btn_reset_cfg').on('click', function () {
                if (confirm('Bạn có chắc muốn khôi phục toàn bộ thông số về mặc định?')) {
                    localStorage.removeItem(STORAGE_KEY);
                    CFG = Object.assign({}, DEFAULT_CONFIG);
                    mountUI();
                    success('Đã khôi phục cài đặt mặc định');
                }
            });

            // Header buttons
            $('#ksk_btn_close').on('click', function () {
                stop();
                $('#ksk_pro_panel').remove();
                $('#ksk_pro_style').remove();
            });

            $('#ksk_btn_min').on('click', function () {
                const $b = $('#ksk_pro_body');
                $b.toggle();
                $(this).text($b.is(':visible') ? '_' : '□');
            });
        }

        function setupDraggable() {
            const panel = document.getElementById('ksk_pro_panel');
            const header = document.getElementById('ksk_pro_header');
            if (!panel || !header) return;

            let ox = 0, oy = 0, drag = false;

            header.addEventListener('mousedown', function (e) {
                if (e.target.tagName === 'BUTTON') return;
                drag = true;
                ox = e.clientX - panel.getBoundingClientRect().left;
                oy = e.clientY - panel.getBoundingClientRect().top;
                panel.style.right = 'auto';
            });

            document.addEventListener('mousemove', function (e) {
                if (!drag) return;
                panel.style.left = Math.max(10, e.clientX - ox) + 'px';
                panel.style.top = Math.max(10, e.clientY - oy) + 'px';
            });

            document.addEventListener('mouseup', function () {
                drag = false;
            });
        }

        // =========================================================================
        // 12. KHỞI TẠO VÀ GLOBAL API EXPORT
        // =========================================================================
        mountUI();

        // Phím tắt Ctrl + Alt + K để ẩn / hiện bảng điều khiển nhanh
        document.addEventListener('keydown', function (e) {
            if (e.ctrlKey && e.altKey && (e.key === 'k' || e.key === 'K')) {
                const p = document.getElementById('ksk_pro_panel');
                if (p) p.style.display = p.style.display === 'none' ? 'block' : 'none';
            }
        });

        // Xuất Global API KSK_AUTO
        window.KSK_AUTO = {
            version: '4.0',
            start,
            pause,
            stop,
            runOne,
            config: CFG,
            done: DONE,
            bnDone: BN_DONE,
            kysoDone: KYSO_DONE,
            checkSmartCaLogin: isSmartCALoginAppeared,
            closeSmartCaLogin: closeSmartCALoginModal,
            saveConfig: saveConfigToStorage,
            loadConfig: loadSavedConfig,
            _destroy: function () {
                stop();
                $('#ksk_pro_panel').remove();
                $('#ksk_pro_style').remove();
            }
        };
    }
})();

