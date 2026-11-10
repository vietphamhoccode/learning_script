// ==UserScript==
// @name         Auto KSK & SmartCA - VNPT HIS
// @namespace    http://tampermonkey.net/
// @version      3.8
// @description  Auto nhap lieu KSK du 18 tuoi va ky so SmartCA sieu toc
// @author       AutoKSK
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    const defaultConfig = {
        autoRun: false,
        enableSign: true,
        autoDisableOnLoginAlert: true,
        speedDelay: 40,

        bpBases: [
            { sys: 100, dia: 60, enabled: true },
            { sys: 110, dia: 70, enabled: true },
            { sys: 120, dia: 80, enabled: true }
        ],
        bpJitter: 3,

        pulseMin: 70,
        pulseMax: 84,
        respMin: 16,
        respMax: 19,
        tempMin: 36.5,
        tempMax: 36.9,

        maleHeightMin: 162,
        maleHeightMax: 175,
        maleWeightMin: 55,
        maleWeightMax: 72,
        femaleHeightMin: 152,
        femaleHeightMax: 164,
        femaleWeightMin: 44,
        femaleWeightMax: 56,

        lyDoKham: 'Kiểm tra khám sàn lọc',
        requiredAddress: 'phường Long Châu',
        maBacSi: '1327430',
        tenBacSi: 'BSCKI. Nguyễn Thị Mỹ Chi',
        noiDungTuanHoan: 'Chưa phát hiện bệnh lý',
        noiDungLamSang: 'Chưa phát hiện bệnh lý',

        tuoiSinhVienMax: 23,
        tuoiNguoiLaoDongMax: 59,

        vaiTro1: 'CKS_NGUOI_KET_LUAN',
        vaiTro2: 'CKS_BENH_VIEN'
    };

    let config = Object.assign({}, defaultConfig);
    let processedPatientsList = [];
    let completedCount = 0;
    let isRunning = false;
    let isPaused = false;

    const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

    async function waitFor(predicateFn, timeout = 5000, interval = 50) {
        const start = Date.now();
        while (Date.now() - start < timeout) {
            try {
                const res = predicateFn();
                if (res) return res;
            } catch (e) { }
            await sleep(interval);
        }
        return false;
    }

    function triggerChange(element) {
        if (!element) return;
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function autoDismissPopups() {
        const jOk = document.querySelector('#popup_ok');
        if (jOk && jOk.offsetParent !== null) {
            jOk.click();
            return true;
        }
        const scaConfirm = document.querySelector('.smartca-alert-button-confirm');
        if (scaConfirm && scaConfirm.offsetParent !== null) {
            scaConfirm.click();
            return true;
        }
        const swalOk = document.querySelector('.swal2-confirm');
        if (swalOk && swalOk.offsetParent !== null) {
            swalOk.click();
            return true;
        }
        const btnDongs = Array.from(document.querySelectorAll('button, input[type="button"]')).filter(b => {
            const t = (b.textContent || b.value || '').trim().toLowerCase();
            return (t === 'đồng ý' || t === 'xác nhận' || t === 'ok' || t === 'xong') && b.offsetParent !== null;
        });
        if (btnDongs.length > 0 && !btnDongs[0].id.includes('kham') && !btnDongs[0].id.includes('luu') && !btnDongs[0].id.includes('btn-ky-so')) {
            btnDongs[0].click();
            return true;
        }
        return false;
    }

    function isSmartCALoginAppeared() {
        const loginDiv = document.querySelector('#pdf-modal-signature-login');
        if (loginDiv) {
            const dialog = loginDiv.closest('.ui-dialog');
            if (dialog && dialog.offsetParent !== null && window.getComputedStyle(dialog).display !== 'none') {
                return loginDiv;
            }
        }
        const titles = Array.from(document.querySelectorAll('.ui-dialog-title'));
        for (let t of titles) {
            if (t.textContent.trim().toUpperCase().includes('ĐĂNG NHẬP SMARTCA')) {
                const dialog = t.closest('.ui-dialog');
                if (dialog && dialog.offsetParent !== null && window.getComputedStyle(dialog).display !== 'none') {
                    return t;
                }
            }
        }
        return null;
    }

    function closeSmartCALoginModal() {
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
            if (t.textContent.trim().toUpperCase().includes('ĐĂNG NHẬP SMARTCA')) {
                const d = t.closest('.ui-dialog');
                if (d) {
                    const c = d.querySelector('.ui-dialog-titlebar-close');
                    if (c) c.click();
                    else d.style.display = 'none';
                }
            }
        }
    }

    function handleSmartCALoginDetected() {
        return !!isSmartCALoginAppeared();
    }

    function randInt(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    function randFloat(min, max, decimals = 1) {
        const str = (Math.random() * (max - min) + min).toFixed(decimals);
        return parseFloat(str);
    }

    function isPatientProcessed(mbn) {
        if (!mbn) return false;
        return processedPatientsList.some(p => p.mbn === mbn);
    }

    function addProcessedPatient(mbn, hoTen, status = 'Hoàn tất') {
        if (!mbn) return;
        processedPatientsList.unshift({
            mbn: mbn,
            hoTen: hoTen,
            time: new Date().toLocaleTimeString(),
            status: status
        });
        if (processedPatientsList.length > 500) processedPatientsList.pop();
    }

    function clearProcessedList() {
        processedPatientsList = [];
        completedCount = 0;
        updateStatCounters();
        addLog('Đã làm mới danh sách bệnh nhân và đặt lại bộ đếm về 0.', 'info');
    }

    function updateStatCounters() {
        const el = document.getElementById('ak-stat-completed');
        if (el) el.textContent = completedCount;
    }

    function resetStats() {
        completedCount = 0;
        updateStatCounters();
        addLog('Đã đặt lại bộ đếm số bệnh nhân hoàn thành về 0.', 'info');
    }

    function setSigningEnabled(enabled, reason = '') {
        config.enableSign = !!enabled;
        const btn = document.getElementById('ak-btn-toggle-sign');
        const desc = document.getElementById('auto-ksk-sign-desc');
        const statusText = document.getElementById('auto-ksk-sign-status-text');

        if (btn) {
            if (config.enableSign) {
                btn.className = 'ak-btn-sign-toggle ak-sign-on';
                btn.innerHTML = '<span>🔐 ĐANG BẬT</span>';
                if (desc) desc.textContent = 'Tự động ký 2 vai trò XML_KSK';
            } else {
                btn.className = 'ak-btn-sign-toggle ak-sign-off';
                btn.innerHTML = '<span>🔓 ĐÃ TẮT</span>';
                if (desc) desc.textContent = reason ? `Đã tắt (${reason})` : 'Bỏ qua bước ký số SmartCA';
            }
        }

        if (statusText) {
            if (config.enableSign) {
                statusText.textContent = 'ĐANG BẬT';
                statusText.style.color = '#2e7d32';
            } else {
                statusText.textContent = reason ? `ĐÃ TẮT (${reason})` : 'ĐÃ TẮT';
                statusText.style.color = '#d32f2f';
            }
        }
    }

    function generateBloodPressure(tuoi, isNu) {
        const availableBases = config.bpBases.filter(b => b.enabled);
        let base;
        if (!availableBases.length) {
            base = { sys: 110, dia: 70 };
        } else if (tuoi >= 60) {
            const high = availableBases.find(b => b.sys >= 120) || availableBases[availableBases.length - 1];
            base = (Math.random() < 0.7) ? high : availableBases[randInt(0, availableBases.length - 1)];
        } else if (tuoi <= 23 || isNu) {
            const low = availableBases.filter(b => b.sys <= 110);
            base = (low.length && Math.random() < 0.75) ? low[randInt(0, low.length - 1)] : availableBases[randInt(0, availableBases.length - 1)];
        } else {
            base = availableBases[randInt(0, availableBases.length - 1)];
        }

        const jitter = Math.max(0, parseInt(config.bpJitter) || 0);
        const deltaSys = jitter ? randInt(-jitter, jitter) : 0;
        const deltaDia = jitter ? randInt(-jitter, jitter) : 0;

        return {
            sys: Math.max(90, Math.min(135, base.sys + deltaSys)),
            dia: Math.max(50, Math.min(90, base.dia + deltaDia))
        };
    }

    function generateVitals(tuoi, gioiTinh) {
        const isNu = (gioiTinh === 'Nữ' || gioiTinh === '2' || gioiTinh === 2);
        const isCaoTuoi = tuoi >= 60;
        const isThanhNien = tuoi <= 23;

        const bp = generateBloodPressure(tuoi, isNu);

        let mach;
        if (isCaoTuoi) mach = randInt(Math.max(68, config.pulseMin), Math.min(78, config.pulseMax));
        else if (isThanhNien) mach = randInt(Math.max(72, config.pulseMin), config.pulseMax);
        else mach = randInt(config.pulseMin, config.pulseMax);

        const nhipTho = randInt(config.respMin, config.respMax);
        const nhietDo = randFloat(config.tempMin, config.tempMax, 1);

        let chieuCao, canNang;
        if (isNu) {
            chieuCao = randInt(config.femaleHeightMin, config.femaleHeightMax);
            canNang = randInt(config.femaleWeightMin, config.femaleWeightMax);
        } else {
            chieuCao = randInt(config.maleHeightMin, config.maleHeightMax);
            canNang = randInt(config.maleWeightMin, config.maleWeightMax);
        }

        const hM = chieuCao / 100.0;
        const bmi = (canNang / (hM * hM)).toFixed(2);

        return { mach, bp, nhipTho, nhietDo, chieuCao, canNang, bmi };
    }

    function pickRandomPatient() {
        const grid = $('#list1');
        if (!grid.length) return null;

        const rowIds = grid.jqGrid('getDataIDs');
        if (!rowIds || !rowIds.length) return null;

        const eligible = [];
        for (let id of rowIds) {
            const data = grid.jqGrid('getRowData', id);
            const mbn = (data.MA_BENH_NHAN || data.MABENHNHAN || '').replace(/<[^>]*>?/gm, '').trim();
            if (mbn && !isPatientProcessed(mbn)) {
                eligible.push({ rowId: id, data: data, mbn: mbn });
            }
        }

        if (!eligible.length) return null;
        const randomIndex = Math.floor(Math.random() * eligible.length);
        return eligible[randomIndex];
    }

    function setDoctorSelect(id) {
        const el = document.getElementById(id);
        if (!el) return;
        const $el = $(el);
        let targetVal = config.maBacSi;
        let optText = config.tenBacSi || '';

        const optByVal = $el.find(`option[value="${targetVal}"]`);
        if (optByVal.length) {
            optText = optByVal.text();
        } else if (config.tenBacSi) {
            const optByText = $el.find('option').filter(function () {
                return $(this).text().toLowerCase().includes(config.tenBacSi.toLowerCase());
            });
            if (optByText.length) {
                targetVal = optByText.val();
                optText = optByText.text();
            }
        }

        if ((!optByVal.length && !optText) || targetVal === '0') {
            const firstValid = $el.find('option').filter(function () {
                const v = $(this).val();
                return v && v !== '0' && v !== '';
            }).first();
            if (firstValid.length) {
                targetVal = firstValid.val();
                optText = firstValid.text();
            }
        }

        $el.val(targetVal);
        $el.trigger('change');
        $el.trigger('chosen:updated');
        triggerChange(el);

        const chosenContainer = document.getElementById(id + '_chosen');
        if (chosenContainer) {
            const span = chosenContainer.querySelector('.chosen-single span');
            if (span && optText) span.textContent = optText;
        }

        const badge = document.getElementById('badge_' + id);
        if (badge) {
            badge.className = 'tt32-badge tt32-badge-done';
            badge.textContent = 'Đã khám';
        }
    }

    function verifyAndEnsureAllKSKFields(isFemale, kskTuoi = 30) {
        let age = parseInt($('#tt32_mau2ksktuoi').val()) || kskTuoi;
        let dtVal = $('#tt32_mau2kskdoituong').val();
        if (!dtVal || dtVal === '') {
            if (age <= config.tuoiSinhVienMax) {
                dtVal = '12';
            } else if (age < (config.tuoiNguoiLaoDongMax + 1)) {
                dtVal = '13';
            } else {
                dtVal = '1';
            }
            $('#tt32_mau2kskdoituong').val(dtVal);
            triggerChange(document.getElementById('tt32_mau2kskdoituong'));
        }

        if (!$('#tt32_mau2kskdantoc').val()) {
            $('#tt32_mau2kskdantoc').val('01');
            triggerChange(document.getElementById('tt32_mau2kskdantoc'));
        }
        if (!$('#tt32_mau2ksknguonchitra').val()) {
            $('#tt32_mau2ksknguonchitra').val('1');
            triggerChange(document.getElementById('tt32_mau2ksknguonchitra'));
        }
        if (!$('#tt32_mau2ksknghenghiep').val()) {
            $('#tt32_mau2ksknghenghiep').val('1');
            triggerChange(document.getElementById('tt32_mau2ksknghenghiep'));
        }

        const lyDo = ($('#tt32_mau2ksklydo').val() || '').trim();
        if (!lyDo) {
            $('#tt32_mau2ksklydo').val(config.lyDoKham || 'Khám sức khỏe định kỳ');
            triggerChange(document.getElementById('tt32_mau2ksklydo'));
        }

        let diachi = ($('#tt32_mau2kskdiachi').val() || '').trim();
        if (!diachi.toLowerCase().includes('long châu')) {
            diachi = diachi ? `${diachi}, ${config.requiredAddress}` : config.requiredAddress;
            $('#tt32_mau2kskdiachi').val(diachi);
            triggerChange(document.getElementById('tt32_mau2kskdiachi'));
        }

        const dateVal = ($('#tt32_mau2kskngaykham').val() || '').trim();
        if (!dateVal) {
            const today = new Date();
            const dStr = ('0' + today.getDate()).slice(-2) + '/' + ('0' + (today.getMonth() + 1)).slice(-2) + '/' + today.getFullYear();
            $('#tt32_mau2kskngaykham').val(dStr);
            triggerChange(document.getElementById('tt32_mau2kskngaykham'));
        }

        const specs = [
            { id: 'tt32_mau2tuanhoan', bs: 'tt32_mau2bacsituanhoan', def: config.noiDungTuanHoan || 'Mạch đều, rõ, không tiếng tim bệnh lý' },
            { id: 'tt32_mau2hohap', bs: 'tt32_mau2bacsihohap', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2tieuhoa', bs: 'tt32_mau2bacsitieuhoa', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2tietnieu', bs: 'tt32_mau2bacsitietnieu', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2noitiet', bs: 'tt32_mau2bacsinoitiet', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2coxuongkhop', bs: 'tt32_mau2bacsixuongkhop', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2thankinh', bs: 'tt32_mau2bacsithankinh', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2tamthan', bs: 'tt32_mau2bacsitamthan', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2ngoaikhoa', bs: 'tt32_mau2bacsingoaikhoa', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2ngkdalieu', bs: 'tt32_mau2bacsidalieu', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' },
            { id: 'tt32_mau2benhvemat', bs: 'tt32_mau2bacsimat', def: 'Bình thường' },
            { id: 'tt32_mau2benhvetai', bs: 'tt32_mau2bacsitaimuihong', def: 'Bình thường' },
            { id: 'tt32_mau2benhverang', bs: 'tt32_mau2bacsiranghammat', def: 'Bình thường' }
        ];

        if (isFemale) {
            specs.push({ id: 'tt32_mau2sanphukhoa', bs: 'tt32_mau2bacsiphukhoa', def: config.noiDungLamSang || 'Chưa phát hiện bệnh lý' });
        }

        for (const s of specs) {
            const elTxt = document.getElementById(s.id);
            if (elTxt && !elTxt.value.trim()) {
                elTxt.value = s.def;
                $(elTxt).val(s.def).trigger('change');
                triggerChange(elTxt);
            }

            const elBs = document.getElementById(s.bs);
            if (elBs && (!elBs.value || elBs.value === '0')) {
                setDoctorSelect(s.bs);
            }
        }

        if (!$('#tt32_mau2khongkinhmatphai').val()) $('#tt32_mau2khongkinhmatphai').val('10/10');
        if (!$('#tt32_mau2khongkinhmattrai').val()) $('#tt32_mau2khongkinhmattrai').val('10/10');
        if (!$('#tt32_mau2taitrainoithuong').val()) $('#tt32_mau2taitrainoithuong').val('5m');
        if (!$('#tt32_mau2taitrainoitham').val()) $('#tt32_mau2taitrainoitham').val('0.5m');
        if (!$('#tt32_mau2taiphainoithuong').val()) $('#tt32_mau2taiphainoithuong').val('5m');
        if (!$('#tt32_mau2taiphainoitham').val()) $('#tt32_mau2taiphainoitham').val('0.5m');
        if (!$('#tt32_mau2ranghamtren').val()) $('#tt32_mau2ranghamtren').val('Bình thường');
        if (!$('#tt32_mau2ranghamduoi').val()) $('#tt32_mau2ranghamduoi').val('Bình thường');

        if (window.jQuery) {
            $('#tt32_mau2ksk-tab3 select').trigger('chosen:updated');
        }
        if (typeof window.tt32_ksk_updateAllBadges_mau2 === 'function') {
            try { window.tt32_ksk_updateAllBadges_mau2(); } catch (e) { }
        }
    }

    function fillKhamLamSang(isNu = false) {
        const noiDung = config.noiDungLamSang || 'Chưa phát hiện bệnh lý';
        const noiDungTuanHoan = config.noiDungTuanHoan || 'Mạch đều, rõ, không tiếng tim bệnh lý';

        const setFieldVal = (id, val) => {
            const el = document.getElementById(id);
            if (!el) return;
            el.value = val;
            $(el).val(val).trigger('input').trigger('change');
            triggerChange(el);
        };

        setFieldVal('tt32_mau2tuanhoan', noiDungTuanHoan);
        setDoctorSelect('tt32_mau2bacsituanhoan');

        setFieldVal('tt32_mau2hohap', noiDung);
        setDoctorSelect('tt32_mau2bacsihohap');

        setFieldVal('tt32_mau2tieuhoa', noiDung);
        setDoctorSelect('tt32_mau2bacsitieuhoa');

        setFieldVal('tt32_mau2tietnieu', noiDung);
        setDoctorSelect('tt32_mau2bacsitietnieu');

        setFieldVal('tt32_mau2noitiet', noiDung);
        setDoctorSelect('tt32_mau2bacsinoitiet');

        setFieldVal('tt32_mau2coxuongkhop', noiDung);
        setDoctorSelect('tt32_mau2bacsixuongkhop');

        setFieldVal('tt32_mau2thankinh', noiDung);
        setDoctorSelect('tt32_mau2bacsithankinh');

        setFieldVal('tt32_mau2tamthan', noiDung);
        setDoctorSelect('tt32_mau2bacsitamthan');

        setFieldVal('tt32_mau2ngoaikhoa', noiDung);
        setDoctorSelect('tt32_mau2bacsingoaikhoa');

        setFieldVal('tt32_mau2ngkdalieu', noiDung);
        setDoctorSelect('tt32_mau2bacsidalieu');

        if (isNu) {
            setFieldVal('tt32_mau2sanphukhoa', noiDung);
            setDoctorSelect('tt32_mau2bacsiphukhoa');
        }

        setFieldVal('tt32_mau2khongkinhmatphai', '10/10');
        setFieldVal('tt32_mau2khongkinhmattrai', '10/10');
        setFieldVal('tt32_mau2benhvemat', 'Bình thường');
        setDoctorSelect('tt32_mau2bacsimat');

        setFieldVal('tt32_mau2taitrainoithuong', '5m');
        setFieldVal('tt32_mau2taitrainoitham', '0.5m');
        setFieldVal('tt32_mau2taiphainoithuong', '5m');
        setFieldVal('tt32_mau2taiphainoitham', '0.5m');
        setFieldVal('tt32_mau2benhvetai', 'Bình thường');
        setDoctorSelect('tt32_mau2bacsitaimuihong');

        setFieldVal('tt32_mau2ranghamtren', 'Bình thường');
        setFieldVal('tt32_mau2ranghamduoi', 'Bình thường');
        setFieldVal('tt32_mau2benhverang', 'Bình thường');
        setDoctorSelect('tt32_mau2bacsiranghammat');

        if (window.jQuery) {
            $('#tt32_mau2ksk-tab3 select').trigger('chosen:updated');
        }
        if (typeof window.tt32_ksk_updateAllBadges_mau2 === 'function') {
            try { window.tt32_ksk_updateAllBadges_mau2(); } catch (e) { }
        }
    }

    function closeKSKModal() {
        const dialogWrap = $('#tt32_mau2_khamkstheomau_div').closest('.ui-dialog');
        if (dialogWrap.length) {
            const closeBtn = dialogWrap.find('.ui-dialog-titlebar-close');
            if (closeBtn.length) closeBtn.click();
        }
        if (window.$ && $('#tt32_mau2_khamkstheomau_div').dialog) {
            try { $('#tt32_mau2_khamkstheomau_div').dialog('close'); } catch (e) { }
        }
        $('#tt32_mau2kskhoten').val('');
        $('#tt32_mau2ksktuoi').val('');
        $('#tt32_mau2ksksocmnd').val('');
        $('#tt32_mau2kskdoituong').val('');
        $('#tt32_mau2ksklydo').val('');
        autoDismissPopups();
    }

    function cancelPatient() {
        const btnHuy = $('#huy');
        if (btnHuy.length && !btnHuy.prop('disabled')) {
            btnHuy.click();
            autoDismissPopups();
        }
    }

    function isSmartCAModalOpen() {
        const c = document.getElementById('smartca-ad-modal-container');
        return !!(c && c.classList.contains('one') && !c.classList.contains('out'));
    }

    async function openSmartCAModal(timeout = 8000) {
        if (handleSmartCALoginDetected()) return false;

        if (isSmartCAModalOpen()) return true;

        const floatBtn = document.querySelector('#smartca-ad-float-button-scanner') ||
            document.querySelector('#smartca-float-button-div');

        if (floatBtn) {
            if (window.jQuery) {
                $('#smartca-ad-float-button-scanner').trigger('click');
            }
            floatBtn.click();
            const childImg = floatBtn.querySelector('img');
            if (childImg) childImg.click();
        }

        const ok = await waitFor(() => {
            if (handleSmartCALoginDetected()) return false;
            return isSmartCAModalOpen();
        }, timeout, 50);

        if (ok) {
            await waitFor(() => document.querySelector('#smartca-tab-item-khac'), 5000, 50);
            await sleep(250);
        }

        return ok;
    }

    function isTabKhacActive() {
        const tab = document.querySelector('#smartca-tab-item-khac');
        if (!tab) return false;
        if (tab.classList.contains('smartca-ad-modal-content-tabs-header-active')) return true;
        const grid = document.querySelector('#smartca-ad-grid-thong-tin-phieu');
        return (grid && grid.offsetParent !== null);
    }

    async function switchToTabKhac(timeout = 8000) {
        if (handleSmartCALoginDetected()) return false;

        await waitFor(() => {
            const l = document.querySelector('#smartca-loading');
            return !l || l.offsetParent === null || window.getComputedStyle(l).display === 'none';
        }, 3000, 50);

        const tab = document.querySelector('#smartca-tab-item-khac');
        if (!tab) return false;

        tab.style.pointerEvents = 'auto';
        if (window.jQuery) {
            $('#smartca-tab-item-khac').trigger('click');
        }
        tab.click();
        const span = tab.querySelector('span');
        if (span) span.click();

        const ok = await waitFor(() => {
            if (handleSmartCALoginDetected()) return false;
            return isTabKhacActive();
        }, timeout, 50);

        await sleep(200);
        return ok;
    }

    function isAlreadySignedXML() {
        const signedBtn = document.querySelector('div[data-type="btn-huy-ky-so"][data-id="XML_KSK_DINH_KY_TREN_18_TUOI"]') ||
            document.querySelector('div[data-type="btn-huy-ky-so"][data-id*="XML_KSK"]');
        return !!signedBtn;
    }

    function findSignButtonXML() {
        const exact = document.querySelector('div.smartca-ad-sign-button-scanner[data-id="XML_KSK_DINH_KY_TREN_18_TUOI"]') ||
            document.querySelector('[data-type="btn-ky-so"][data-id="XML_KSK_DINH_KY_TREN_18_TUOI"]') ||
            document.querySelector('div[data-id="XML_KSK_DINH_KY_TREN_18_TUOI"]');
        if (exact) return exact;

        const list = Array.from(document.querySelectorAll('.smartca-ad-sign-button-scanner, div[data-type="btn-ky-so"]'));
        for (let el of list) {
            const id = (el.getAttribute('data-id') || '').toUpperCase();
            if (id.includes('XML_KSK') || id.includes('KSK_DINH_KY')) return el;
        }
        return null;
    }

    function closeSmartCAModals() {
        const closeBtn = document.getElementById('smartca-ad-modal-close-button');
        if (closeBtn) {
            if (window.jQuery) $('#smartca-ad-modal-close-button').trigger('click');
            closeBtn.click();
        }

        const container = document.getElementById('smartca-ad-modal-container');
        if (container) {
            container.classList.remove('one');
            container.classList.add('out');
        }

        const roleDialog = $('#smartca-ad-modal-select-vai-tro-sign-xml').closest('.ui-dialog');
        if (roleDialog.length) {
            const c = roleDialog.find('.ui-dialog-titlebar-close');
            if (c.length) c.click();
        }
        if (window.$ && $('#smartca-ad-modal-select-vai-tro-sign-xml').dialog) {
            try { $('#smartca-ad-modal-select-vai-tro-sign-xml').dialog('close'); } catch (e) { }
        }

        const loginModal = $('#pdf-modal-signature-login').closest('.ui-dialog');
        if (loginModal.length) {
            const c = loginModal.find('.ui-dialog-titlebar-close');
            if (c.length) c.click();
        }

        autoDismissPopups();
    }

    function isSigningInProgress() {
        const scanner = document.getElementById('scanner-loading');
        if (scanner && window.getComputedStyle(scanner).display !== 'none') return true;
        const loading = document.getElementById('smartca-loading');
        if (loading && loading.offsetParent !== null && window.getComputedStyle(loading).display !== 'none') return true;
        const alertEl = document.getElementById('smartca-alert');
        if (alertEl && alertEl.offsetParent !== null) return true;
        const roleSel = document.getElementById('slb-vai-tro-sign-xml');
        if (roleSel && roleSel.offsetParent !== null && window.getComputedStyle(roleSel).display !== 'none') return true;
        if (isSmartCALoginAppeared()) return true;
        return false;
    }

    async function waitForRoleSigningCompletion(roleLabel, timeout = 180000) {
        const startTime = Date.now();
        let lastReportSec = 0;

        while (Date.now() - startTime < timeout) {
            if (isSmartCALoginAppeared()) {
                closeSmartCALoginModal();
                return 'LOGIN_DETECTED';
            }

            const elapsedSec = Math.floor((Date.now() - startTime) / 1000);
            if (elapsedSec > 0 && elapsedSec % 5 === 0 && elapsedSec !== lastReportSec) {
                lastReportSec = elapsedSec;
                updateCurrentStep(`${roleLabel}: Đang chờ xác nhận ký (${elapsedSec}s)...`);
            }

            const alertEl = document.getElementById('smartca-alert');
            if (alertEl) {
                const textSpan = alertEl.querySelector('.smartca-alert-content-text-wrapper span');
                const rawMsg = (textSpan ? (textSpan.innerText || textSpan.textContent) : (alertEl.innerText || alertEl.textContent) || '').trim();
                const lowerMsg = rawMsg.toLowerCase();

                const isSuccess = lowerMsg.includes('thành công') ||
                    lowerMsg.includes('đã thực hiện ký số') ||
                    alertEl.querySelector('.fa-check-circle, [typed="success"]') !== null;

                const isExplicitFailure = lowerMsg.includes('chưa ký') ||
                    lowerMsg.includes('không thành công') ||
                    lowerMsg.includes('đã hủy') ||
                    lowerMsg.includes('thất bại') ||
                    lowerMsg.includes('tài khoản chưa cấu hình') ||
                    lowerMsg.includes('chưa cấu hình') ||
                    lowerMsg.includes('lỗi đọc thông tin') ||
                    alertEl.querySelector('.fa-times-circle, [typed="error"]') !== null;

                const isPromptNotice = lowerMsg.includes('yêu cầu ký số') ||
                    lowerMsg.includes('đã được gửi') ||
                    lowerMsg.includes('ứng dụng') ||
                    lowerMsg.includes('điện thoại') ||
                    lowerMsg.includes('vui lòng kiểm tra') ||
                    lowerMsg.includes('đang xác thực') ||
                    lowerMsg.includes('vui lòng đợi');

                if (isSuccess) {
                    addLog(`[${roleLabel}] ✅ Hệ thống thông báo: "${rawMsg}". Bấm Xác nhận...`, 'success');
                    const confirmBtn = alertEl.querySelector('.smartca-alert-button-confirm');
                    if (confirmBtn) confirmBtn.click();
                    await waitFor(() => !document.getElementById('smartca-alert'), 4000, 50);
                    await sleep(400);
                    return true;
                } else if (isExplicitFailure) {
                    addLog(`[${roleLabel}] ❌ Hệ thống báo lỗi/hủy: "${rawMsg}". Dừng ký vai trò này.`, 'warn');
                    const confirmBtn = alertEl.querySelector('.smartca-alert-button-confirm');
                    if (confirmBtn) confirmBtn.click();
                    await waitFor(() => !document.getElementById('smartca-alert'), 4000, 50);
                    await sleep(400);
                    return false;
                } else if (isPromptNotice) {
                    addLog(`[${roleLabel}] 📲 Hệ thống nhắc: "${rawMsg}". Tiếp tục chờ xác nhận trên điện thoại...`, 'info');
                    const confirmBtn = alertEl.querySelector('.smartca-alert-button-confirm');
                    if (confirmBtn) confirmBtn.click();
                    await waitFor(() => !document.getElementById('smartca-alert'), 4000, 50);
                    await sleep(400);
                } else {
                    const scannerOn = document.getElementById('scanner-loading');
                    const isScanner = scannerOn && window.getComputedStyle(scannerOn).display !== 'none';
                    const loadingOn = document.getElementById('smartca-loading');
                    const isLoading = loadingOn && loadingOn.offsetParent !== null && window.getComputedStyle(loadingOn).display !== 'none';

                    if (isScanner || isLoading) {
                        addLog(`[${roleLabel}] Thông báo: "${rawMsg}" (Đang ký số -> Bấm xác nhận và tiếp tục chờ)...`, 'info');
                        const confirmBtn = alertEl.querySelector('.smartca-alert-button-confirm');
                        if (confirmBtn) confirmBtn.click();
                        await waitFor(() => !document.getElementById('smartca-alert'), 4000, 50);
                        await sleep(400);
                    } else {
                        addLog(`[${roleLabel}] Thông báo hệ thống: "${rawMsg}".`, 'warn');
                        const confirmBtn = alertEl.querySelector('.smartca-alert-button-confirm');
                        if (confirmBtn) confirmBtn.click();
                        await waitFor(() => !document.getElementById('smartca-alert'), 4000, 50);
                        await sleep(400);
                        return false;
                    }
                }
            }

            const jContainer = document.getElementById('popup_container');
            if (jContainer && jContainer.offsetParent !== null) {
                const jMsg = (document.getElementById('popup_message')?.innerText || '').trim();
                const jOk = document.getElementById('popup_ok');
                if (jMsg.toLowerCase().includes('thành công')) {
                    addLog(`[${roleLabel}] ✅ Thông báo jAlert: "${jMsg}". Bấm OK...`, 'success');
                    if (jOk) jOk.click();
                    await sleep(400);
                    return true;
                } else {
                    addLog(`[${roleLabel}] ⚠️ Thông báo jAlert: "${jMsg}". Bấm OK...`, 'warn');
                    if (jOk) jOk.click();
                    await sleep(400);
                    return false;
                }
            }

            await sleep(150);
        }

        addLog(`Quá thời gian chờ phản hồi ký số cho ${roleLabel} (${Math.round(timeout / 1000)}s).`, 'warn');
        return false;
    }

    async function executeSmartCASigning(vitals, tuoi) {
        addLog('Bắt đầu quy trình Ký số SmartCA...', 'info');

        if (handleSmartCALoginDetected()) return false;

        addLog('Mở bảng SmartCA Scanner...', 'info');
        const opened = await openSmartCAModal(8000);
        if (!opened) {
            addLog('Không thể mở hộp thoại SmartCA.', 'warn');
            return false;
        }

        if (handleSmartCALoginDetected()) return false;
        await sleep(300);

        addLog('Chuyển sang tab "Khác"...', 'info');
        const tabOk = await switchToTabKhac(8000);
        if (!tabOk) {
            addLog('Chưa kích hoạt được tab "Khác", thử lại...', 'warn');
            await sleep(300);
            await switchToTabKhac(5000);
        }

        if (handleSmartCALoginDetected()) return false;

        addLog('Chờ hệ thống tải danh sách văn bản từ máy chủ...', 'info');
        await waitFor(() => {
            const l1 = document.querySelector('#smartca-loading');
            const l2 = document.querySelector('#load_smartca-ad-grid-thong-tin-phieu');
            const isL1 = l1 && l1.offsetParent !== null && window.getComputedStyle(l1).display !== 'none';
            const isL2 = l2 && l2.offsetParent !== null && window.getComputedStyle(l2).display !== 'none';
            return !isL1 && !isL2;
        }, 8000, 100);

        await sleep(300);

        addLog('Đang chờ phát hiện nút ký số XML_KSK...', 'info');
        let btnSignXML = await waitFor(() => {
            if (handleSmartCALoginDetected()) return null;
            return findSignButtonXML();
        }, 15000, 100);

        if (!btnSignXML) {
            if (isAlreadySignedXML()) {
                addLog('Văn bản XML_KSK đã được ký số thành công trước đó.', 'success');
                await sleep(300);
                closeSmartCAModals();
                return true;
            }

            addLog('Làm mới lại tab "Khác" để nạp lại văn bản...', 'info');
            const tabKhac = document.querySelector('#smartca-tab-item-khac');
            if (tabKhac) {
                if (window.jQuery) $(tabKhac).trigger('click');
                tabKhac.click();
            }
            await sleep(400);

            await waitFor(() => {
                const l1 = document.querySelector('#smartca-loading');
                const l2 = document.querySelector('#load_smartca-ad-grid-thong-tin-phieu');
                const isL1 = l1 && l1.offsetParent !== null && window.getComputedStyle(l1).display !== 'none';
                const isL2 = l2 && l2.offsetParent !== null && window.getComputedStyle(l2).display !== 'none';
                return !isL1 && !isL2;
            }, 8000, 100);

            btnSignXML = await waitFor(() => {
                if (handleSmartCALoginDetected()) return null;
                return findSignButtonXML();
            }, 10000, 100);
        }

        if (!btnSignXML) {
            if (isAlreadySignedXML()) {
                addLog('Văn bản XML_KSK đã có chữ ký số.', 'success');
                await sleep(300);
                closeSmartCAModals();
                return true;
            }

            addLog('Không tìm thấy nút ký số XML_KSK sau khi chờ nạp.', 'warn');
            closeSmartCAModals();
            return false;
        }

        addLog('Đã phát hiện nút ký số XML_KSK! Chuẩn bị thao tác ký...', 'success');
        btnSignXML.scrollIntoView({ behavior: 'smooth', block: 'center' });
        await sleep(400);

        if (window.jQuery) {
            $(btnSignXML).trigger('click');
        }
        btnSignXML.click();

        addLog('Chờ xuất hiện bảng chọn vai trò ký...', 'info');
        const roleModal = await waitFor(() => {
            if (handleSmartCALoginDetected()) return null;
            const sel = document.querySelector('#slb-vai-tro-sign-xml');
            const btn = document.querySelector('#btn-ky-so-xml-ca');
            const dialog = sel?.closest('.ui-dialog');
            const isVisible = dialog ? (dialog.offsetParent !== null && window.getComputedStyle(dialog).display !== 'none') : (sel && sel.offsetParent !== null);
            return (sel && btn && isVisible) ? { sel, btn } : false;
        }, 12000, 100);

        if (!roleModal) {
            addLog('Không xuất hiện bảng chọn vai trò ký.', 'warn');
            closeSmartCAModals();
            return false;
        }

        await sleep(500);

        const oldAlert = document.getElementById('smartca-alert');
        if (oldAlert) {
            const oldBtn = oldAlert.querySelector('.smartca-alert-button-confirm');
            if (oldBtn) oldBtn.click();
            else oldAlert.remove();
            await sleep(200);
        }

        addLog(`[BƯỚC 1/2] Chọn vai trò 1: "${config.vaiTro1}"...`, 'info');
        $('#slb-vai-tro-sign-xml').val(config.vaiTro1).trigger('change');
        triggerChange(document.getElementById('slb-vai-tro-sign-xml'));
        await sleep(400);

        const btnSign1 = document.getElementById('btn-ky-so-xml-ca');
        if (!btnSign1) {
            addLog('Không tìm thấy nút "btn-ky-so-xml-ca" để ký vai trò 1.', 'warn');
            closeSmartCAModals();
            return false;
        }

        addLog(`[BƯỚC 1/2] Nhấn nút KÝ SỐ cho vai trò 1 (${config.vaiTro1})...`, 'info');
        btnSign1.click();
        await sleep(400);

        if (isSmartCALoginAppeared()) {
            closeSmartCALoginModal();
            closeSmartCAModals();
            return 'LOGIN_DETECTED';
        }

        addLog(`[BƯỚC 1/2] Đang chờ hệ thống xử lý và báo "Ký số thành công!" cho vai trò 1...`, 'info');
        updateCurrentStep(`Chờ xác nhận ký: ${config.vaiTro1}`);
        const role1Success = await waitForRoleSigningCompletion(`Vai trò 1 (${config.vaiTro1})`, 180000);

        if (role1Success === 'LOGIN_DETECTED' || isSmartCALoginAppeared()) {
            closeSmartCALoginModal();
            closeSmartCAModals();
            return 'LOGIN_DETECTED';
        }

        if (!role1Success) {
            addLog('⚠️ Ký vai trò 1 (Người kết luận) CHƯA THÀNH CÔNG! TUÂN THỦ QUY TẮC: Dừng lại, không được ký vai trò 2.', 'warn');
            closeSmartCAModals();
            return false;
        }

        addLog('✅ VAI TRÒ 1 ĐÃ KÝ VÀ BÁO THÀNH CÔNG! Đang chuẩn bị chuyển sang vai trò 2...', 'success');
        await sleep(800);

        const oldAlert2 = document.getElementById('smartca-alert');
        if (oldAlert2) {
            const oldBtn2 = oldAlert2.querySelector('.smartca-alert-button-confirm');
            if (oldBtn2) oldBtn2.click();
            else oldAlert2.remove();
            await sleep(200);
        }

        addLog(`[BƯỚC 2/2] Kiểm tra bảng chọn vai trò cho vai trò 2: "${config.vaiTro2}"...`, 'info');
        let sel2 = document.getElementById('slb-vai-tro-sign-xml');
        let isSel2Visible = sel2 && sel2.offsetParent !== null && window.getComputedStyle(sel2).display !== 'none';

        if (!isSel2Visible) {
            addLog('Mở lại bảng chọn vai trò ký để ký vai trò 2...', 'info');
            const btnXmlAgain = findSignButtonXML();
            if (btnXmlAgain) {
                btnXmlAgain.click();
                await sleep(500);
            }
            await waitFor(() => {
                const s = document.getElementById('slb-vai-tro-sign-xml');
                return (s && s.offsetParent !== null && window.getComputedStyle(s).display !== 'none') ? s : false;
            }, 8000, 100);
            sel2 = document.getElementById('slb-vai-tro-sign-xml');
        }

        if (!sel2) {
            addLog('Không tìm thấy hộp chọn vai trò cho vai trò 2.', 'warn');
            closeSmartCAModals();
            return false;
        }

        addLog(`[BƯỚC 2/2] Chọn vai trò 2: "${config.vaiTro2}"...`, 'info');
        $(sel2).val(config.vaiTro2).trigger('change');
        triggerChange(sel2);
        await sleep(400);

        const btnSign2 = document.getElementById('btn-ky-so-xml-ca');
        if (!btnSign2) {
            addLog('Không tìm thấy nút "btn-ky-so-xml-ca" để ký vai trò 2.', 'warn');
            closeSmartCAModals();
            return false;
        }

        addLog(`[BƯỚC 2/2] Nhấn nút KÝ SỐ cho vai trò 2 (${config.vaiTro2})...`, 'info');
        btnSign2.click();

        addLog(`[BƯỚC 2/2] Đang chờ hệ thống xử lý và báo "Ký số thành công!" cho vai trò 2...`, 'info');
        updateCurrentStep(`Chờ xác nhận ký: ${config.vaiTro2}`);
        const role2Success = await waitForRoleSigningCompletion(`Vai trò 2 (${config.vaiTro2})`, 180000);

        if (role2Success === 'LOGIN_DETECTED' || isSmartCALoginAppeared()) {
            closeSmartCALoginModal();
            closeSmartCAModals();
            return 'LOGIN_DETECTED';
        }

        if (!role2Success) {
            addLog('⚠️ Ký vai trò 2 (Chữ ký bệnh viện) chưa thành công!', 'warn');
            closeSmartCAModals();
            return false;
        }

        addLog('🎉 ĐÃ KÝ THÀNH CÔNG CẢ 2 VAI TRÒ THEO ĐÚNG THỨ TỰ QUY ĐỊNH!', 'success');

        addLog('Hoàn tất ký 2 vai trò. Đóng hộp thoại ký số.', 'success');
        await sleep(300);
        closeSmartCAModals();
        await sleep(400);
        autoDismissPopups();
        return true;
    }

    async function openAndFillKSK(vitals, tuoi, isNu = false, expectedName = '') {
        addLog('Mở bảng KSK đủ 18...', 'info');
        const btnKSK18 = $('#khamsuckhoetheodoituongdu18');
        if (!btnKSK18.length) {
            addLog('Không tìm thấy nút KSK đủ 18.', 'warn');
            return 'NOT_FOUND';
        }

        $('#tt32_mau2kskhoten').val('');
        $('#tt32_mau2ksktuoi').val('');
        $('#tt32_mau2ksksocmnd').val('');
        $('#tt32_mau2kskdoituong').val('');
        $('#tt32_mau2ksklydo').val('');

        btnKSK18.click();

        const kskDiv = await waitFor(() => {
            const d = document.getElementById('tt32_mau2_khamkstheomau_div');
            return (d && window.getComputedStyle(d).display !== 'none') ? d : false;
        }, 4000, 30);

        if (!kskDiv) {
            addLog('Hộp thoại KSK đủ 18 không xuất hiện.', 'warn');
            return 'NOT_FOUND';
        }

        await waitFor(() => {
            const curName = ($('#tt32_mau2kskhoten').val() || '').trim();
            if (!curName) return false;
            if (expectedName) {
                const cleanExp = expectedName.toUpperCase().replace(/\s+/g, ' ');
                const cleanCur = curName.toUpperCase().replace(/\s+/g, ' ');
                return cleanCur.includes(cleanExp) || cleanExp.includes(cleanCur);
            }
            return curName.length > 0;
        }, 5000, 50);

        await waitFor(() => (!window.jQuery || window.jQuery.active === 0), 4000, 50);
        await sleep(250);

        const kskGenderVal = $('#tt32_mau2kskgioitinh').val();
        const isFemale = isNu || kskGenderVal === '0';

        let cccd = ($('#tt32_mau2ksksocmnd').val() || '').trim();
        if (cccd.length === 11) {
            cccd = '0' + cccd;
            $('#tt32_mau2ksksocmnd').val(cccd);
            triggerChange(document.getElementById('tt32_mau2ksksocmnd'));
            addLog(`Bổ sung 0 đầu CCCD: ${cccd}`, 'info');
        }

        if (cccd.length !== 12) {
            addLog(`CCCD không đủ 12 số ("${cccd}"). Bỏ qua ca khám này.`, 'warn');
            closeKSKModal();
            return 'INVALID_CCCD';
        }

        let diachi = ($('#tt32_mau2kskdiachi').val() || '').trim();
        if (!diachi.toLowerCase().includes('long châu')) {
            diachi = diachi ? `${diachi}, ${config.requiredAddress}` : config.requiredAddress;
            $('#tt32_mau2kskdiachi').val(diachi);
            triggerChange(document.getElementById('tt32_mau2kskdiachi'));
        }

        const lyDo = config.lyDoKham || 'Khám sức khỏe định kỳ';
        $('#tt32_mau2ksklydo').val(lyDo);
        triggerChange(document.getElementById('tt32_mau2ksklydo'));

        let kskTuoi = parseInt($('#tt32_mau2ksktuoi').val()) || tuoi;
        let doituongVal = '13';
        if (kskTuoi <= config.tuoiSinhVienMax) {
            doituongVal = '12';
        } else if (kskTuoi < (config.tuoiNguoiLaoDongMax + 1)) {
            doituongVal = '13';
        } else {
            doituongVal = '1';
        }
        $('#tt32_mau2kskdoituong').val(doituongVal);
        triggerChange(document.getElementById('tt32_mau2kskdoituong'));

        if (!$('#tt32_mau2kskdantoc').val()) {
            $('#tt32_mau2kskdantoc').val('01');
            triggerChange(document.getElementById('tt32_mau2kskdantoc'));
        }
        if (!$('#tt32_mau2ksknguonchitra').val()) {
            $('#tt32_mau2ksknguonchitra').val('1');
            triggerChange(document.getElementById('tt32_mau2ksknguonchitra'));
        }
        if (!$('#tt32_mau2ksknghenghiep').val()) {
            $('#tt32_mau2ksknghenghiep').val('1');
            triggerChange(document.getElementById('tt32_mau2ksknghenghiep'));
        }

        if ($('#tt32_mau2gdmacbenhtruyennhiem').length) {
            $('#tt32_mau2gdmacbenhtruyennhiem').val('0');
            triggerChange(document.getElementById('tt32_mau2gdmacbenhtruyennhiem'));
        }
        if ($('#tt32_mau2gdtenbenhcuthe').length && !$('#tt32_mau2gdtenbenhcuthe').val()) {
            $('#tt32_mau2gdtenbenhcuthe').val('Không');
            triggerChange(document.getElementById('tt32_mau2gdtenbenhcuthe'));
        }
        if ($('#tt32_mau2tenbenhtatbanthan').length && !$('#tt32_mau2tenbenhtatbanthan').val()) {
            $('#tt32_mau2tenbenhtatbanthan').val('Không');
            triggerChange(document.getElementById('tt32_mau2tenbenhtatbanthan'));
        }
        if ($('#tt32_mau2thuocdangdungbanthan').length && !$('#tt32_mau2thuocdangdungbanthan').val()) {
            $('#tt32_mau2thuocdangdungbanthan').val('Không');
            triggerChange(document.getElementById('tt32_mau2thuocdangdungbanthan'));
        }
        if (isFemale && $('#tt32_mau2tiensuthaisan').length && !$('#tt32_mau2tiensuthaisan').val()) {
            $('#tt32_mau2tiensuthaisan').val('Bình thường');
            triggerChange(document.getElementById('tt32_mau2tiensuthaisan'));
        }

        $('#tt32_mau2chieucao').val(vitals.chieuCao);
        $('#tt32_mau2cannang').val(vitals.canNang);
        $('#tt32_mau2bmi').val(vitals.bmi);
        $('#tt32_mau2kskhuyetapcao').val(vitals.bp.sys);
        $('#tt32_mau2kskhuyetapthap').val(vitals.bp.dia);
        $('#tt32_mau2kskmach').val(vitals.mach);

        addLog(`Điền đầy đủ lâm sàng các chuyên khoa (BS: ${config.maBacSi} - ${config.tenBacSi})...`, 'info');
        const tab3Anchor = document.querySelector('a[href*="tt32_mau2ksk-tab3"]');
        if (tab3Anchor) {
            tab3Anchor.click();
            await sleep(80);
        }

        fillKhamLamSang(isFemale);
        await sleep(120);
        verifyAndEnsureAllKSKFields(isFemale, kskTuoi);
        await sleep(120);

        addLog('Lưu bảng KSK đủ 18...', 'info');
        $('#tt32_mau2luuthongtin').click();

        let saveResult = 'TIMEOUT';
        await waitFor(() => {
            const popupMsg = document.querySelector('#popup_message');
            if (popupMsg && popupMsg.offsetParent !== null) {
                const text = (popupMsg.textContent || '').trim();
                if (text.includes('Đã cập nhật') || text.toLowerCase().includes('thành công')) {
                    saveResult = 'SUCCESS';
                    autoDismissPopups();
                    return true;
                }
                if (text.toLowerCase().includes('vui lòng') || text.toLowerCase().includes('không đúng') || text.toLowerCase().includes('lỗi')) {
                    addLog(`Bảng KSK báo lỗi: ${text}`, 'warn');
                    saveResult = 'ERROR';
                    autoDismissPopups();
                    return true;
                }
            }
            if (autoDismissPopups()) {
                saveResult = 'SUCCESS';
                return true;
            }
            return false;
        }, 3000, 30);

        await sleep(150);
        autoDismissPopups();
        closeKSKModal();
        await sleep(150);

        if (saveResult === 'ERROR') {
            addLog('Lưu hồ sơ KSK đủ 18 thất bại do chưa đầy đủ hoặc không hợp lệ.', 'warn');
            return 'SAVE_ERROR';
        }

        addLog('Đã điền và lưu đầy đủ tiêu chí KSK đủ 18!', 'success');
        return 'SUCCESS';
    }

    async function processSinglePatient() {
        if (isSigningInProgress()) {
            addLog('Hệ thống đang trong tiến trình ký số, không thể đổi bệnh nhân lúc này!', 'warn');
            return false;
        }

        if (handleSmartCALoginDetected()) {
            addLog('Phát hiện Đăng nhập SmartCA trước khi thực hiện.', 'warn');
        }

        addLog('Tìm bệnh nhân ngẫu nhiên...', 'info');
        const target = pickRandomPatient();
        if (!target) return false;

        const { rowId, data, mbn } = target;
        const hoTen = (data.TEN_BENH_NHAN || data.TEN_BENH_NHAN_HT || 'Bệnh nhân').replace(/<[^>]*>?/gm, '').trim();
        let tuoi = parseInt(data.TUOI) || 30;
        const gioiTinh = (data.GIOI_TINH || '').trim();

        addLog(`Chọn ca: ${hoTen} (Mã: ${mbn}, ${tuoi} tuổi, ${gioiTinh || 'Chưa rõ'})`, 'info');

        $('#list1').jqGrid('setSelection', rowId, true);
        const rowDom = document.getElementById(rowId);
        if (rowDom) rowDom.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        await waitFor(() => {
            const mayte = $('#mayte').val();
            return (mayte && mayte.trim() === mbn) || ($('#kham').length && !$('#kham').prop('disabled'));
        }, 2000, 30);

        const btnKham = $('#kham');
        if (btnKham.length && !btnKham.prop('disabled')) {
            addLog('Nhấn nút "Khám"...', 'info');
            btnKham.click();
            autoDismissPopups();
            await sleep(config.speedDelay);
        }

        await waitFor(() => !$('#mach').prop('disabled') || !$('#luu').prop('disabled'), 2000, 30);

        const vitals = generateVitals(tuoi, gioiTinh);
        addLog(`Sinh hiệu: Mạch ${vitals.mach}, HA ${vitals.bp.sys}/${vitals.bp.dia}, Thở ${vitals.nhipTho}, Nhiệt ${vitals.nhietDo}°C, Cao ${vitals.chieuCao}cm, Nặng ${vitals.canNang}kg`, 'info');

        $('#mach').val(vitals.mach);
        triggerChange(document.getElementById('mach'));
        $('#nhiptho').val(vitals.nhipTho);
        triggerChange(document.getElementById('nhiptho'));
        $('#chieucao').val(vitals.chieuCao);
        triggerChange(document.getElementById('chieucao'));
        $('#nhietdo').val(vitals.nhietDo);
        triggerChange(document.getElementById('nhietdo'));
        $('#huyetaptren').val(vitals.bp.sys);
        triggerChange(document.getElementById('huyetaptren'));
        $('#huyetapduoi').val(vitals.bp.dia);
        triggerChange(document.getElementById('huyetapduoi'));
        $('#cannang').val(vitals.canNang);
        triggerChange(document.getElementById('cannang'));
        if ($('#chisobmi').length) {
            $('#chisobmi').val(vitals.bmi);
            triggerChange(document.getElementById('chisobmi'));
        }

        autoDismissPopups();

        const isNu = gioiTinh.toLowerCase().includes('nữ') || gioiTinh.toLowerCase().includes('nu') || data.GIOI_TINH === false || data.GIOI_TINH_ID === '2' || data.GIOI_TINH_ID === 2;
        const kskRes = await openAndFillKSK(vitals, tuoi, isNu, hoTen);
        if (kskRes === 'NOT_FOUND') {
            cancelPatient();
            return false;
        }
        if (kskRes === 'INVALID_CCCD') {
            cancelPatient();
            addProcessedPatient(mbn, hoTen, 'Bỏ qua: CCCD không hợp lệ');
            return true;
        }
        if (kskRes !== 'SUCCESS') {
            addLog('Hồ sơ KSK đủ 18 chưa đạt tiêu chuẩn, hủy ca và chuyển sang ca khác...', 'warn');
            cancelPatient();
            addProcessedPatient(mbn, hoTen, 'Bỏ qua: Lưu KSK không đạt');
            return true;
        }

        if (config.enableSign) {
            if (isSmartCALoginAppeared()) {
                addLog('Phát hiện ĐĂNG NHẬP SMARTCA! Tắt ký số, hủy ca này và chuyển sang ca khác...', 'warn');
                closeSmartCALoginModal();
                closeSmartCAModals();
                setSigningEnabled(false, 'Đăng nhập SmartCA xuất hiện');
                cancelPatient();
                autoDismissPopups();
                addProcessedPatient(mbn, hoTen, 'Bỏ qua ký số (Đăng nhập SmartCA)');
                return true;
            }

            addLog('Tiến hành quy trình ký số SmartCA (bắt buộc hoàn tất cả 2 vai trò)...', 'info');
            updateCurrentStep('Đang thực hiện ký số SmartCA...');
            await sleep(350);
            const signRes = await executeSmartCASigning(vitals, tuoi);

            if (signRes === 'LOGIN_DETECTED' || isSmartCALoginAppeared()) {
                addLog('Phát hiện ĐĂNG NHẬP SMARTCA! Tắt ký số, hủy ca này và chuyển sang ca khác...', 'warn');
                closeSmartCALoginModal();
                closeSmartCAModals();
                setSigningEnabled(false, 'Đăng nhập SmartCA xuất hiện');
                cancelPatient();
                autoDismissPopups();
                addProcessedPatient(mbn, hoTen, 'Bỏ qua ký số (Đăng nhập SmartCA)');
                return true;
            }

            if (!signRes) {
                addLog('⛔ KÝ SỐ CHƯA HOÀN TẤT THÀNH CÔNG! Tuyệt đối không lưu và không đổi bệnh nhân.', 'warn');
                updateCurrentStep('Ký số chưa xong - Tạm dừng');
                pauseLoop();
                return false;
            }
            addLog('🎉 ĐÃ KÝ SỐ HOÀN TẤT VÀ THÀNH CÔNG CẢ 2 VAI TRÒ! Chuẩn bị lưu ca khám...', 'success');
        }

        addLog('Lưu thông tin tại danh sách bệnh nhân...', 'info');
        const btnLuuBN = $('#luu');
        if (btnLuuBN.length && !btnLuuBN.prop('disabled')) {
            btnLuuBN.click();
            await waitFor(() => autoDismissPopups(), 2000, 30);
            autoDismissPopups();
        }

        await sleep(150);

        cancelPatient();
        autoDismissPopups();

        completedCount++;
        addProcessedPatient(mbn, hoTen, 'Hoàn tất');
        updateStatCounters();
        addLog(`✅ Hoàn tất thành công: ${hoTen} (Mã: ${mbn}) [Hoàn thành: ${completedCount}]`, 'success');
        return true;
    }

    async function startLoop() {
        if (isRunning) return;
        isRunning = true;
        isPaused = false;
        updateUIState();
        addLog('🚀 BẮT ĐẦU VẬN HÀNH AUTO...', 'success');

        while (isRunning) {
            if (isPaused) {
                await sleep(150);
                continue;
            }

            try {
                const ok = await processSinglePatient();
                if (!ok) {
                    if (isPaused) {
                        addLog('Tiến trình tạm dừng do ca hiện tại chưa hoàn tất. Bạn có thể kiểm tra và bấm BẮT ĐẦU lại khi sẵn sàng.', 'info');
                    } else {
                        addLog('Dừng do không còn bệnh nhân hợp lệ hoặc gặp sự cố.', 'warn');
                        stopLoop();
                    }
                    break;
                }
            } catch (err) {
                addLog(`Lỗi xử lý ca: ${err.message}`, 'warn');
                pauseLoop();
                break;
            }

            await sleep(config.speedDelay * 2);
        }
    }

    function pauseLoop() {
        if (!isRunning) return;
        isPaused = !isPaused;
        const pauseBtn = document.querySelector('#ak-btn-pause');
        if (pauseBtn) pauseBtn.textContent = isPaused ? '▶ TIẾP TỤC' : '⏸ TẠM DỪNG';
        updateUIState();
        addLog(isPaused ? 'Đã tạm dừng tiến trình.' : 'Tiếp tục tiến trình.', 'warn');
    }

    function stopLoop() {
        isRunning = false;
        isPaused = false;
        updateUIState();
        addLog('⏹ ĐÃ DỪNG TIẾN TRÌNH.', 'warn');
    }

    async function stepOne() {
        if (isRunning) return;
        addLog('Khám 1 bệnh nhân...', 'info');
        updateCurrentStep('Đang khám 1 ca...');
        try {
            await processSinglePatient();
        } catch (e) {
            addLog(`Lỗi: ${e.message}`, 'warn');
            cancelPatient();
        }
        updateCurrentStep('Chờ lệnh tiếp theo');
    }

    function updateUIState() {
        const startBtn = document.querySelector('#ak-btn-start');
        const pauseBtn = document.querySelector('#ak-btn-pause');
        const stopBtn = document.querySelector('#ak-btn-stop');
        const stepBtn = document.querySelector('#ak-btn-step');

        if (startBtn) startBtn.disabled = isRunning;
        if (pauseBtn) {
            pauseBtn.disabled = !isRunning;
            pauseBtn.textContent = isPaused ? '▶ TIẾP TỤC' : '⏸ TẠM DỪNG';
        }
        if (stopBtn) stopBtn.disabled = !isRunning;
        if (stepBtn) stepBtn.disabled = isRunning;

        updateCurrentStep(isRunning ? (isPaused ? 'Tạm dừng' : 'Đang chạy tự động') : 'Sẵn sàng');
    }

    function updateCurrentStep(text) {
        const el = document.getElementById('auto-ksk-current-step');
        if (el) el.textContent = text;
    }

    function updateStepStatus(text) {
        updateCurrentStep(text);
    }

    function addLog(msg, type = 'info') {
        const logBox = document.getElementById('auto-ksk-log-content');
        if (!logBox) return;

        const time = new Date().toLocaleTimeString();
        const line = document.createElement('div');
        line.className = `log-line log-${type}`;
        line.textContent = `[${time}] ${msg}`;

        logBox.appendChild(line);
        logBox.scrollTop = logBox.scrollHeight;

        const lines = logBox.querySelectorAll('.log-line');
        if (lines.length > 200) lines[0].remove();
    }

    function createUI() {
        if (document.getElementById('auto-ksk-floating-panel')) return;

        const container = document.createElement('div');
        container.id = 'auto-ksk-floating-panel';
        container.innerHTML = `
        <style>
            #auto-ksk-floating-panel {
                position: fixed;
                top: 75px;
                right: 20px;
                width: 440px;
                background: #ffffff;
                border-radius: 10px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.25), 0 0 1px rgba(0,0,0,0.2);
                z-index: 999999;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                font-size: 13px;
                color: #333;
                overflow: hidden;
                border: 1px solid #dcdfe6;
            }
            #auto-ksk-header {
                background: linear-gradient(135deg, #1e88e5, #1565c0);
                color: #fff;
                padding: 10px 14px;
                display: flex;
                align-items: center;
                justify-content: space-between;
                cursor: move;
                user-select: none;
                font-weight: 600;
                font-size: 14px;
            }
            .auto-ksk-title { display: flex; align-items: center; gap: 8px; }
            .auto-ksk-badge { font-size: 11px; padding: 2px 7px; border-radius: 10px; background: rgba(255,255,255,0.25); }
            .auto-ksk-header-btn {
                background: rgba(255,255,255,0.2);
                border: none;
                color: #fff;
                width: 24px;
                height: 24px;
                border-radius: 4px;
                cursor: pointer;
                font-size: 12px;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .auto-ksk-header-btn:hover { background: rgba(255,255,255,0.4); }
            #auto-ksk-body { padding: 12px; max-height: 82vh; overflow-y: auto; }
            .auto-ksk-action-bar { display: grid; grid-template-columns: 2fr 1fr 1fr 1fr; gap: 8px; margin-bottom: 10px; }
            .ak-btn {
                padding: 8px 10px;
                border: none;
                border-radius: 6px;
                font-weight: 600;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 5px;
                transition: all 0.15s ease;
            }
            .ak-btn-primary { background: #2e7d32; color: #fff; box-shadow: 0 2px 6px rgba(46,125,50,0.3); }
            .ak-btn-primary:hover { background: #1b5e20; }
            .ak-btn-warning { background: #ed6c02; color: #fff; }
            .ak-btn-warning:hover { background: #c75a00; }
            .ak-btn-danger { background: #d32f2f; color: #fff; }
            .ak-btn-danger:hover { background: #9a0007; }
            .ak-btn-info { background: #0288d1; color: #fff; }
            .ak-btn-info:hover { background: #01579b; }

            .auto-ksk-counter-card {
                background: linear-gradient(135deg, #e8f5e9, #f1f8e9);
                border: 1px solid #c8e6c9;
                border-radius: 8px;
                padding: 10px 14px;
                margin-bottom: 10px;
                display: flex;
                align-items: center;
                justify-content: space-between;
                box-sizing: border-box;
            }
            .counter-card-info {
                display: flex;
                flex-direction: column;
            }
            .counter-card-label {
                font-size: 11px;
                font-weight: 700;
                color: #2e7d32;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 2px;
            }
            .counter-card-sub {
                font-size: 11px;
                color: #558b2f;
            }
            .counter-card-count-box {
                display: flex;
                align-items: baseline;
                gap: 5px;
            }
            .counter-card-number {
                font-size: 26px;
                font-weight: 800;
                color: #1b5e20;
                line-height: 1;
            }
            .counter-card-unit {
                font-size: 13px;
                font-weight: 600;
                color: #2e7d32;
            }
            .counter-card-reset {
                font-size: 11px;
                color: #1565c0;
                cursor: pointer;
                text-decoration: underline;
                margin-left: 8px;
            }

            .auto-ksk-status-card {
                background: #f8fafc;
                border: 1px solid #e2e8f0;
                border-radius: 6px;
                padding: 8px 12px;
                margin-bottom: 10px;
                font-size: 12px;
            }
            .auto-ksk-status-row { display: flex; justify-content: space-between; margin-bottom: 4px; }
            .auto-ksk-status-row:last-child { margin-bottom: 0; }
            .auto-ksk-status-highlight { font-weight: 600; color: #1e88e5; }

            #auto-ksk-smartca-banner {
                background: #f8fafc;
                border: 1px solid #cbd5e1;
                border-radius: 8px;
                padding: 10px 12px;
                margin-bottom: 10px;
                display: flex;
                align-items: center;
                justify-content: space-between;
                box-sizing: border-box;
            }
            .smartca-banner-left {
                display: flex;
                align-items: center;
                gap: 8px;
            }
            .smartca-banner-title {
                font-weight: 700;
                color: #1e293b;
                font-size: 12px;
            }
            .smartca-banner-sub {
                font-size: 11px;
                color: #64748b;
            }
            .ak-btn-sign-toggle {
                padding: 6px 14px;
                font-size: 12px;
                font-weight: 700;
                border-radius: 20px;
                cursor: pointer;
                transition: all 0.2s ease;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                gap: 6px;
                box-sizing: border-box;
                border: none;
            }
            .ak-sign-on {
                background: #2e7d32;
                color: #fff;
                box-shadow: 0 2px 6px rgba(46,125,50,0.3);
            }
            .ak-sign-on:hover { background: #1b5e20; }
            .ak-sign-off {
                background: #e2e8f0;
                color: #64748b;
                box-shadow: 0 1px 3px rgba(0,0,0,0.05);
            }
            .ak-sign-off:hover { background: #cbd5e1; color: #334155; }

            .auto-ksk-nav-tabs {
                display: flex;
                border-bottom: 1px solid #e0e0e0;
                margin-bottom: 10px;
            }
            .auto-ksk-nav-tab {
                padding: 6px 12px;
                cursor: pointer;
                font-weight: 600;
                color: #666;
                border-bottom: 2px solid transparent;
            }
            .auto-ksk-nav-tab.active {
                color: #1e88e5;
                border-bottom-color: #1e88e5;
            }
            .auto-ksk-tab-content { display: none; }
            .auto-ksk-tab-content.active { display: block; }

            .ak-form-group { margin-bottom: 10px; }
            .ak-form-label { display: block; font-weight: 600; margin-bottom: 4px; font-size: 12px; color: #444; }
            .ak-input {
                width: 100%;
                padding: 6px 8px;
                border: 1px solid #ccc;
                border-radius: 4px;
                box-sizing: border-box;
                font-size: 12px;
            }
            .ak-input:focus { border-color: #1e88e5; outline: none; }
            .ak-grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
            .ak-grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6px; }

            .auto-ksk-log-box {
                background: #1e1e1e;
                color: #e0e0e0;
                border-radius: 6px;
                padding: 8px;
                height: 120px;
                overflow-y: auto;
                font-family: Consolas, monospace;
                font-size: 11px;
                line-height: 1.4;
                margin-top: 10px;
            }
            .log-line { margin-bottom: 3px; word-break: break-all; }
            .log-info { color: #81d4fa; }
            .log-success { color: #a5d6a7; font-weight: bold; }
            .log-warn { color: #ffe082; }

            .ak-switch-label {
                display: inline-flex;
                align-items: center;
                gap: 5px;
                cursor: pointer;
                user-select: none;
                font-size: 12px;
            }
        </style>

        <div id="auto-ksk-header">
            <div class="auto-ksk-title">
                <span>⚡ Auto KSK & SmartCA</span>
                <span class="auto-ksk-badge">v3.5</span>
            </div>
            <div style="display: flex; gap: 6px;">
                <button class="auto-ksk-header-btn" id="auto-ksk-btn-min" title="Thu nhỏ">_</button>
                <button class="auto-ksk-header-btn" id="auto-ksk-btn-close" title="Đóng">×</button>
            </div>
        </div>

        <div id="auto-ksk-body">
            <div class="auto-ksk-action-bar">
                <button class="ak-btn ak-btn-primary" id="ak-btn-start">▶ BẮT ĐẦU</button>
                <button class="ak-btn ak-btn-warning" id="ak-btn-pause">⏸ TẠM DỪNG</button>
                <button class="ak-btn ak-btn-danger" id="ak-btn-stop">⏹ DỪNG</button>
                <button class="ak-btn ak-btn-info" id="ak-btn-step" title="Khám 1 bệnh nhân">⏭ 1 CA</button>
            </div>

            <div class="auto-ksk-counter-card">
                <div class="counter-card-info">
                    <span class="counter-card-label">SỐ BỆNH NHÂN HOÀN THÀNH</span>
                    <span class="counter-card-sub">Lưu & huỷ thành công</span>
                </div>
                <div class="counter-card-count-box">
                    <span class="counter-card-number" id="ak-stat-completed">0</span>
                    <span class="counter-card-unit">bệnh nhân</span>
                    <span id="ak-btn-reset-stats" class="counter-card-reset" title="Đặt lại về 0">↺ Đặt lại</span>
                </div>
            </div>

            <div class="auto-ksk-status-card">
                <div class="auto-ksk-status-row">
                    <span>Thao tác hiện tại:</span>
                    <span class="auto-ksk-status-highlight" id="auto-ksk-current-step">Sẵn sàng vận hành</span>
                </div>
                <div class="auto-ksk-status-row">
                    <span>Trạng thái Ký số:</span>
                    <span id="auto-ksk-sign-status-text" style="font-weight: 600; color: #2e7d32;">ĐANG BẬT</span>
                </div>
            </div>

            <div id="auto-ksk-smartca-banner">
                <div class="smartca-banner-left">
                    <span style="font-size: 18px;">🔐</span>
                    <div>
                        <div class="smartca-banner-title">KÝ SỐ SMARTCA</div>
                        <div class="smartca-banner-sub" id="auto-ksk-sign-desc">Tự động ký 2 vai trò XML_KSK</div>
                    </div>
                </div>
                <button id="ak-btn-toggle-sign" class="ak-btn-sign-toggle ak-sign-on" title="Nhấn để bật / tắt ký số SmartCA">
                    <span>🔐 ĐANG BẬT</span>
                </button>
            </div>

            <div class="auto-ksk-nav-tabs">
                <div class="auto-ksk-nav-tab active" data-tab="tab-vitals">Sinh hiệu</div>
                <div class="auto-ksk-nav-tab" data-tab="tab-ksk">Bác sĩ & KSK</div>
                <div class="auto-ksk-nav-tab" data-tab="tab-speed">Tốc độ & List</div>
            </div>

            <div class="auto-ksk-tab-content active" id="tab-vitals">
                <div class="ak-form-group">
                    <label class="ak-form-label">Mức Huyết áp (Random trong 3 mức & dao động):</label>
                    <div style="display: flex; gap: 12px; margin-bottom: 6px;">
                        <label class="ak-switch-label"><input type="checkbox" id="ak-bp-100-60"> 100/60</label>
                        <label class="ak-switch-label"><input type="checkbox" id="ak-bp-110-70"> 110/70</label>
                        <label class="ak-switch-label"><input type="checkbox" id="ak-bp-120-80"> 120/80</label>
                    </div>
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <span style="font-size: 12px; color: #666;">Độ dao động (± mmHg):</span>
                        <input type="number" id="ak-bp-jitter" class="ak-input" style="width: 70px;" min="0" max="10">
                    </div>
                </div>

                <div class="ak-grid-2">
                    <div class="ak-form-group">
                        <label class="ak-form-label">Mạch (nhịp/phút):</label>
                        <div style="display: flex; gap: 4px;">
                            <input type="number" id="ak-pulse-min" class="ak-input" placeholder="Min">
                            <input type="number" id="ak-pulse-max" class="ak-input" placeholder="Max">
                        </div>
                    </div>
                    <div class="ak-form-group">
                        <label class="ak-form-label">Nhịp thở (lần/phút):</label>
                        <div style="display: flex; gap: 4px;">
                            <input type="number" id="ak-resp-min" class="ak-input" placeholder="Min">
                            <input type="number" id="ak-resp-max" class="ak-input" placeholder="Max">
                        </div>
                    </div>
                </div>

                <div class="ak-form-group">
                    <label class="ak-form-label">Nhiệt độ (°C):</label>
                    <div style="display: flex; gap: 8px;">
                        <input type="number" step="0.1" id="ak-temp-min" class="ak-input" placeholder="Min">
                        <input type="number" step="0.1" id="ak-temp-max" class="ak-input" placeholder="Max">
                    </div>
                </div>

                <div class="ak-grid-2">
                    <div class="ak-form-group">
                        <label class="ak-form-label">Nam - Cao/Nặng:</label>
                        <div style="display: flex; gap: 4px;">
                            <input type="number" id="ak-male-h-min" class="ak-input" placeholder="Cao min">
                            <input type="number" id="ak-male-w-min" class="ak-input" placeholder="Nặng min">
                        </div>
                    </div>
                    <div class="ak-form-group">
                        <label class="ak-form-label">Nữ - Cao/Nặng:</label>
                        <div style="display: flex; gap: 4px;">
                            <input type="number" id="ak-female-h-min" class="ak-input" placeholder="Cao min">
                            <input type="number" id="ak-female-w-min" class="ak-input" placeholder="Nặng min">
                        </div>
                    </div>
                </div>
            </div>

            <div class="auto-ksk-tab-content" id="tab-ksk">
                <div class="ak-grid-2">
                    <div class="ak-form-group">
                        <label class="ak-form-label">Mã Bác Sĩ KSK:</label>
                        <input type="text" id="ak-cfg-mabs" class="ak-input">
                    </div>
                    <div class="ak-form-group">
                        <label class="ak-form-label">Tên Bác Sĩ KSK:</label>
                        <input type="text" id="ak-cfg-tenbs" class="ak-input">
                    </div>
                </div>
                <div class="ak-form-group">
                    <label class="ak-form-label">Lý do khám KSK:</label>
                    <input type="text" id="ak-cfg-lydo" class="ak-input">
                </div>
                <div class="ak-form-group">
                    <label class="ak-form-label">Nội dung Khám lâm sàng:</label>
                    <input type="text" id="ak-cfg-noidung" class="ak-input">
                </div>
                <div class="ak-form-group">
                    <label class="ak-form-label">Địa chỉ bắt buộc bổ sung:</label>
                    <input type="text" id="ak-cfg-diachi" class="ak-input">
                </div>
            </div>

            <div class="auto-ksk-tab-content" id="tab-speed">
                <div class="ak-form-group">
                    <label class="ak-form-label">Độ trễ thao tác (ms):</label>
                    <input type="number" id="ak-cfg-speed" class="ak-input" min="20" max="2000" step="10">
                </div>
                <div class="ak-form-group">
                    <label class="ak-form-label">Quản lý danh sách đã khám (Bộ nhớ tạm):</label>
                    <button class="ak-btn ak-btn-warning" id="ak-btn-clear-processed" style="width: 100%;">
                        🧹 Làm mới danh sách & đặt lại bộ đếm
                    </button>
                </div>
            </div>

            <div class="auto-ksk-log-box" id="auto-ksk-log-content">
                <div class="log-line log-info">[Hệ thống] Sẵn sàng tự động khám KSK & ký số SmartCA.</div>
            </div>
        </div>
        `;

        document.body.appendChild(container);
        setupDrag(container);
        bindEvents(container);
        loadConfigToUI();
        setSigningEnabled(config.enableSign);
        updateStatCounters();
    }

    function setupDrag(panel) {
        const header = panel.querySelector('#auto-ksk-header');
        let isDragging = false;
        let startX, startY, initialLeft, initialTop;

        header.addEventListener('mousedown', (e) => {
            if (e.target.tagName === 'BUTTON') return;
            isDragging = true;
            startX = e.clientX;
            startY = e.clientY;

            const rect = panel.getBoundingClientRect();
            initialLeft = rect.left;
            initialTop = rect.top;

            panel.style.right = 'auto';
            panel.style.left = `${initialLeft}px`;
            panel.style.top = `${initialTop}px`;

            document.addEventListener('mousemove', onMouseMove);
            document.addEventListener('mouseup', onMouseUp);
        });

        function onMouseMove(e) {
            if (!isDragging) return;
            const dx = e.clientX - startX;
            const dy = e.clientY - startY;
            panel.style.left = `${Math.max(10, initialLeft + dx)}px`;
            panel.style.top = `${Math.max(10, initialTop + dy)}px`;
        }

        function onMouseUp() {
            isDragging = false;
            document.removeEventListener('mousemove', onMouseMove);
            document.removeEventListener('mouseup', onMouseUp);
        }
    }

    function bindEvents(panel) {
        panel.querySelector('#auto-ksk-btn-close').addEventListener('click', () => {
            panel.style.display = 'none';
        });

        panel.querySelector('#auto-ksk-btn-min').addEventListener('click', () => {
            const body = panel.querySelector('#auto-ksk-body');
            body.style.display = (body.style.display === 'none') ? 'block' : 'none';
        });

        panel.querySelectorAll('.auto-ksk-nav-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                panel.querySelectorAll('.auto-ksk-nav-tab').forEach(t => t.classList.remove('active'));
                panel.querySelectorAll('.auto-ksk-tab-content').forEach(c => c.classList.remove('active'));

                tab.classList.add('active');
                const targetId = tab.getAttribute('data-tab');
                const targetContent = panel.querySelector(`#${targetId}`);
                if (targetContent) targetContent.classList.add('active');
            });
        });

        panel.querySelector('#ak-btn-start').addEventListener('click', startLoop);
        panel.querySelector('#ak-btn-pause').addEventListener('click', pauseLoop);
        panel.querySelector('#ak-btn-stop').addEventListener('click', stopLoop);
        panel.querySelector('#ak-btn-step').addEventListener('click', stepOne);

        const btnToggleSign = panel.querySelector('#ak-btn-toggle-sign');
        if (btnToggleSign) {
            btnToggleSign.addEventListener('click', () => {
                const nextState = !config.enableSign;
                setSigningEnabled(nextState);
                addLog(`Ký số SmartCA: ${nextState ? 'BẬT' : 'TẮT'}`, nextState ? 'info' : 'warn');
            });
        }

        const resetStatsBtn = panel.querySelector('#ak-btn-reset-stats');
        if (resetStatsBtn) {
            resetStatsBtn.addEventListener('click', () => {
                resetStats();
            });
        }

        panel.querySelector('#ak-btn-clear-processed').addEventListener('click', clearProcessedList);

        bindConfigInputs(panel);
    }

    function bindConfigInputs(panel) {
        const bp100 = panel.querySelector('#ak-bp-100-60');
        const bp110 = panel.querySelector('#ak-bp-110-70');
        const bp120 = panel.querySelector('#ak-bp-120-80');

        const updateBpConfig = () => {
            config.bpBases[0].enabled = bp100.checked;
            config.bpBases[1].enabled = bp110.checked;
            config.bpBases[2].enabled = bp120.checked;
        };

        if (bp100) bp100.addEventListener('change', updateBpConfig);
        if (bp110) bp110.addEventListener('change', updateBpConfig);
        if (bp120) bp120.addEventListener('change', updateBpConfig);

        const bindNumber = (selector, key) => {
            const input = panel.querySelector(selector);
            if (!input) return;
            input.addEventListener('change', () => {
                const val = parseFloat(input.value);
                if (!isNaN(val)) config[key] = val;
            });
        };

        const bindText = (selector, key) => {
            const input = panel.querySelector(selector);
            if (!input) return;
            input.addEventListener('change', () => {
                config[key] = input.value.trim();
            });
        };

        bindNumber('#ak-bp-jitter', 'bpJitter');
        bindNumber('#ak-pulse-min', 'pulseMin');
        bindNumber('#ak-pulse-max', 'pulseMax');
        bindNumber('#ak-resp-min', 'respMin');
        bindNumber('#ak-resp-max', 'respMax');
        bindNumber('#ak-temp-min', 'tempMin');
        bindNumber('#ak-temp-max', 'tempMax');

        bindNumber('#ak-male-h-min', 'maleHeightMin');
        bindNumber('#ak-male-w-min', 'maleWeightMin');
        bindNumber('#ak-female-h-min', 'femaleHeightMin');
        bindNumber('#ak-female-w-min', 'femaleWeightMin');

        bindNumber('#ak-cfg-speed', 'speedDelay');
        bindText('#ak-cfg-mabs', 'maBacSi');
        bindText('#ak-cfg-tenbs', 'tenBacSi');
        bindText('#ak-cfg-lydo', 'lyDoKham');
        bindText('#ak-cfg-noidung', 'noiDungLamSang');
        bindText('#ak-cfg-diachi', 'requiredAddress');
    }

    function loadConfigToUI() {
        const setVal = (id, val) => {
            const el = document.getElementById(id);
            if (el) el.value = val;
        };
        const setCheck = (id, checked) => {
            const el = document.getElementById(id);
            if (el) el.checked = !!checked;
        };

        setCheck('ak-bp-100-60', config.bpBases[0].enabled);
        setCheck('ak-bp-110-70', config.bpBases[1].enabled);
        setCheck('ak-bp-120-80', config.bpBases[2].enabled);
        setVal('ak-bp-jitter', config.bpJitter);

        setVal('ak-pulse-min', config.pulseMin);
        setVal('ak-pulse-max', config.pulseMax);
        setVal('ak-resp-min', config.respMin);
        setVal('ak-resp-max', config.respMax);
        setVal('ak-temp-min', config.tempMin);
        setVal('ak-temp-max', config.tempMax);

        setVal('ak-male-h-min', config.maleHeightMin);
        setVal('ak-male-w-min', config.maleWeightMin);
        setVal('ak-female-h-min', config.femaleHeightMin);
        setVal('ak-female-w-min', config.femaleWeightMin);

        setVal('ak-cfg-speed', config.speedDelay);
        setVal('ak-cfg-mabs', config.maBacSi);
        setVal('ak-cfg-tenbs', config.tenBacSi);
        setVal('ak-cfg-lydo', config.lyDoKham);
        setVal('ak-cfg-noidung', config.noiDungLamSang);
        setVal('ak-cfg-diachi', config.requiredAddress);
    }

    function init() {
        const checkReady = setInterval(() => {
            if (document.body && window.jQuery) {
                clearInterval(checkReady);
                createUI();
                addLog('Hệ thống HIS đã sẵn sàng. Giao diện Auto v3.8 đã tải xong.', 'success');
            }
        }, 500);
    }

    init();

    document.addEventListener('keydown', (e) => {
        if (e.ctrlKey && e.altKey && (e.key === 'k' || e.key === 'K')) {
            const p = document.getElementById('auto-ksk-floating-panel');
            if (p) p.style.display = (p.style.display === 'none') ? 'block' : 'none';
        }
    });

})();
