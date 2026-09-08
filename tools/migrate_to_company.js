#!/usr/bin/env node
/**
 * Di trú dữ liệu WorkDay từ bản MỘT-TÀI-KHOẢN sang bản NHIỀU CƠ SỞ.
 *
 *   employees/{id}            ->  companies/{companyId}/employees/{id}
 *   attendance/{eId}_{ngày}   ->  companies/{companyId}/attendance/{eId}_{ngày}
 *   settings/app              ->  companies/{companyId}/settings/app
 *
 * GIỮ NGUYÊN DOC ID, nhất là của `attendance`: doc ID ghép
 * `{employeeId}_{yyyy-MM-dd}` chính là cơ chế chống trùng "một bản ghi công
 * mỗi nhân viên mỗi ngày" (luật §0.3). Vì vậy chạy lại script nhiều lần cũng
 * không sinh bản ghi trùng - lần sau chỉ ghi đè lần trước.
 *
 * `companyId` = uid Firebase của chủ cơ sở. Lấy uid ở
 * Console > Authentication > Users (cho chủ đăng nhập một lần trên bản mới là
 * có uid), hoặc Firestore > users.
 *
 * CÁCH DÙNG
 *   npm install firebase-admin
 *   node tools/migrate_to_company.js --key ./service-account.json --company <uid>
 *   node tools/migrate_to_company.js --key ./service-account.json --company <uid> --commit
 *
 * Không có `--commit` thì chỉ in ra sẽ chuyển những gì, KHÔNG ghi gì cả.
 * Service account tải ở Console > Project settings > Service accounts.
 * ĐỪNG commit file service account vào git.
 *
 * Script KHÔNG xoá dữ liệu cũ ở gốc. Kiểm tra bản mới chạy đúng rồi hãy xoá
 * bằng tay trong Console - rules mới đã chặn hết 4 collection cũ nên chúng
 * chỉ còn chiếm chỗ, không ai đọc được nữa.
 */

const admin = require('firebase-admin');
const path = require('path');

function parseArgs(argv) {
  const out = { commit: false };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--key') out.key = argv[++i];
    else if (a === '--company') out.company = argv[++i];
    else if (a === '--commit') out.commit = true;
    else if (a === '-h' || a === '--help') out.help = true;
    else {
      console.error(`Tham so la: ${a}`);
      process.exit(1);
    }
  }
  return out;
}

const args = parseArgs(process.argv);

if (args.help || !args.key || !args.company) {
  console.log(
    'Cach dung:\n' +
      '  node tools/migrate_to_company.js --key ./service-account.json ' +
      '--company <uid> [--commit]\n\n' +
      '  --key      duong dan file service account JSON (bat buoc)\n' +
      '  --company  companyId = uid Firebase cua chu co so (bat buoc)\n' +
      '  --commit   ghi that. Khong co co nay thi chi in ra xem truoc.\n',
  );
  process.exit(args.help ? 0 : 1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(args.key))),
});

const db = admin.firestore();
const root = db.collection('companies').doc(args.company);

/** Firestore gioi han 500 lenh moi batch - chia lo 450 nhu app. */
async function copyCollection(name) {
  const snap = await db.collection(name).get();
  if (snap.empty) {
    console.log(`  ${name}: khong co document nao, bo qua`);
    return 0;
  }

  let batch = db.batch();
  let ops = 0;
  let done = 0;

  for (const doc of snap.docs) {
    if (args.commit) {
      batch.set(root.collection(name).doc(doc.id), doc.data());
      ops++;
      if (ops === 450) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    done++;
  }
  if (args.commit && ops > 0) await batch.commit();

  console.log(`  ${name}: ${done} document`);
  return done;
}

(async () => {
  console.log('');
  console.log('=====================================================');
  console.log(' DI TRU DU LIEU WORKDAY -> companies/{companyId}');
  console.log('=====================================================');
  console.log('');
  console.log(`Co so (companyId): ${args.company}`);
  console.log(args.commit ? 'Che do           : GHI THAT' : 'Che do           : XEM TRUOC (khong ghi gi)');
  console.log('');

  let total = 0;
  for (const name of ['employees', 'attendance', 'settings']) {
    total += await copyCollection(name);
  }

  // Document co so + ho so nguoi dung: lay ten co so tu settings/app cu.
  const oldSettings = await db.collection('settings').doc('app').get();
  const orgName = (oldSettings.exists && oldSettings.data().orgName) || 'WorkDay';
  const oldUser = await db.collection('app_user').doc('main').get();
  const account = (oldUser.exists && oldUser.data().account) || '';

  console.log('');
  console.log(`  companies/${args.company}: orgName="${orgName}"`);
  console.log(`  users/${args.company}: account="${account}"`);

  if (args.commit) {
    await root.set(
      {
        orgName,
        ownerAccount: account,
        active: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await db.collection('users').doc(args.company).set(
      {
        account,
        displayName: (oldUser.exists && oldUser.data().displayName) || orgName,
        companyId: args.company,
      },
      { merge: true },
    );
  }

  console.log('');
  if (args.commit) {
    console.log(`Xong. Da chuyen ${total} document sang companies/${args.company}.`);
    console.log('Du lieu cu o goc VAN CON - kiem tra app chay dung roi xoa tay.');
  } else {
    console.log(`Xem truoc xong: se chuyen ${total} document. Them --commit de ghi that.`);
  }
  console.log('');
  process.exit(0);
})().catch((e) => {
  console.error('');
  console.error('Loi khi di tru:', e.message);
  process.exit(1);
});
