# ⚡ Quick Test - Browse Files Button

## 🎯 2-Minute Test

### 1. Open Console
```bash
open -a Console
```
Click "Start" → Search: `NitNab`

### 2. Test Browse Files
In NitNab:
- Click "Browse Files"
- Select an audio file
- Click "Open"

### 3. Watch for These Messages

✅ **SUCCESS** - You should see:
```
🔴 STEP 1: Browse Files button clicked
🔴 STEP 3: File picker callback fired
🔴 STEP 4: Access granted: true
🔴 STEP 5: addFiles() called
🔴 STEP 6: Validation SUCCESS
🔴 STEP 8: Company picker should now appear
```

❌ **FAILURE** - If you see:
- Nothing after STEP 1
- "Access granted: false"
- "Validation FAILED"
- "DUPLICATE detected"
- "NO FILES TO ADD"

### 4. What to Share

Copy and paste the **ENTIRE console output** with all 🔴 messages.

---

## 🚨 Common Issues

**No logs appear**:
```bash
# Use this instead
log stream --predicate 'process == "NitNab"' --level debug
```

**Says "duplicate"**:
```bash
./diagnose.sh --nuke
```

**Validation fails**:
Try a different audio file from Desktop or Documents

---

## ✅ Success = All These Happen

1. File picker opens ✅
2. Company picker appears ✅  
3. File shows in list ✅
4. Console shows steps 1-12 ✅

---

**Full details**: See `TEST_BROWSE_FILES.md`
