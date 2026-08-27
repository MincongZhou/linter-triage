# zlint v3 项目证书检测内容详解

## 一、项目整体架构

zlint 是密歇根大学 zmap 团队开发的 **X.509 PKI 证书合规性检查工具**。当前项目为 **v3 版本**，不仅能检测证书，还扩展到了 **CRL（证书吊销列表）** 和 **OCSP 响应**。

### 检测对象（`v3/zlint.go` 中的三个入口）

| 入口函数 | 检测对象 | 说明 |
|---|---|---|
| `LintCertificate()` | `x509.Certificate` | 检测 X.509 证书（最主要的检测） |
| `LintRevocationList()` | `x509.RevocationList` | 检测 CRL 证书吊销列表 |
| `LintOcspResponse()` | `ocsp.Response` | 检测 OCSP 在线证书状态响应 |

### 每条 lint 的接口（`v3/lint/base.go`）

- `CheckApplies()` — 判断该检测项是否适用于当前证书（不适用则返回 `NA`）
- `CheckEffective()` — 判断证书签发日期是否在规范生效日期范围内（不在则返回 `NE`）
- `Execute()` — 实际执行检测逻辑

### 结果状态（`v3/lint/result.go`）

| 状态 | 含义 |
|---|---|
| `pass` | 通过 |
| `info` | 提示信息（仅提醒，不算违规） |
| `warn` | 警告（名称以 `w_` 开头的 lint） |
| `error` | 错误/违规（名称以 `e_` 开头的 lint） |
| `fatal` | 致命错误（lint 本身 panic 时产生） |
| `NA` | 不适用（该检测项与证书类型无关） |
| `NE` | 不生效（证书签发日期早于/晚于规范生效期） |

---

## 二、规范来源（`v3/lint/source.go`）

lint 规则按依据的规范分成 10 大来源，对应 `v3/lints/` 下的 10 个子目录：

| 目录 | 来源 | 规范说明 |
|---|---|---|
| `rfc/` | RFC 5280/3279/5480/5891/6960/6962/8813 | 通用 X.509/PKI 国际标准（最基础、最大的检测集） |
| `cabf_br/` | CABF_BR | CA/Browser Forum《基线要求》(Baseline Requirements)，针对 TLS 服务器证书 |
| `cabf_cs_br/` | CABF_CS_BR | CA/B Forum《代码签名基线要求》 |
| `cabf_smime_br/` | CABF_SMIME_BR | CA/B Forum《S/MIME 邮件证书基线要求》 |
| `cabf_ev/` | CABF_EV | CA/B Forum《扩展验证(EV)证书指南》 |
| `mozilla/` | Mozilla | Mozilla 根证书存储(CA Certificate Program)策略 |
| `apple/` | Apple | Apple 根证书存储策略 |
| `chrome/` | Chrome | Chrome 根证书存储策略 |
| `community/` | Community | 社区共识性检查 |
| `etsi/` | ETSI_ESI | 欧洲电信标准协会 ETSI EN 319 系列（电子签名/合格证书 QC） |

---

## 三、检测内容详解（按证书主题分类）

### 1. 证书基础字段（RFC 5280 第 4.1 节）

| 检测项（代表 lint） | 检测内容 |
|---|---|
| `e_serial_number_not_positive` | **序列号必须为正整数**（不能为 0 或负数），且不超过 20 字节 |
| `e_cert_extensions_version_not_3` | 含扩展的证书**版本必须是 v3**（RFC 5280 要求扩展只能出现在 v3） |
| `e_cert_unique_identifier_version_not_2_or_3` | 唯一标识符字段只在 v2/v3 中允许 |
| `e_cert_contains_unique_identifier` | 不允许包含 `subjectUniqueID`/`issuerUniqueID` 字段（RFC 5280 不推荐使用） |
| `e_cert_ext_invalid_der` | 扩展字段必须使用**合法的 DER 编码** |
| `e_basic_constr_invalid_der` | BasicConstraints 扩展的 DER 编码必须合法 |
| `e_eku_critical_improperly` | 部分扩展被错误地标记为 critical |
| `e_ext_duplicate_extension` | 同一 OID 扩展**不允许重复出现** |
| `e_ext_cannot_be_empty_seq` | 扩展值不允许是空序列 |

### 2. 有效期（Validity）

| 检测项 | 检测内容 |
|---|---|
| `e_sub_cert_valid_time_longer_than_398_days` | 2020-09-01 后签发的 TLS 服务器证书**有效期不得超过 398 天**（Apple 与 CA/B BR 均有此要求） |
| `w_sub_cert_valid_time_longer_than_825_days` | 更早期证书有效期不得超过 825 天（历史要求） |
| `e_utc_time_...` / `e_generalized_time_...` | 时间字段格式：2050 年前必须用 UTC 时间，2050 年后必须用 GeneralizedTime |
| `e_validity_time_not_positive` | 证书有效期长度必须为正 |

### 3. Subject / Issuer 名称字段（证书主体信息）

| 检测项 | 检测内容 |
|---|---|
| `e_ca_subject_field_empty` | **CA 证书的 Subject 不允许为空**（RFC 5280） |
| `e_ca_country_name_missing` / `e_ca_country_name_invalid` | CA 证书必须有合法的国家代码（2 字母 ISO） |
| `e_ca_common_name_missing` | 根 CA 证书必须包含 Common Name |
| `e_ca_organization_name_missing` | CA 证书必须有组织名（根 CA 要求） |
| `e_ca_dns_name_invalid` | Subject CN 中的 DNS 名称必须合法 |
| `e_subject_contains_noninformational_value` | Subject 中不允许包含私人邮箱、电话号码等非机构信息 |
| `w_subject_common_name_included` / `e_subject_common_name_not_from_san` | 新规下 CN 应从 SAN 中复制，不允许独立设置 |
| `e_subject_contains_reserved_arp` / `e_subject_contains_reserved_ip` | 不允许包含保留的 ARPA 域名 / 保留 IP 地址 |
| `e_cab_dv_conflicts_with_*` | **DV（域名验证）证书不允许**在 Subject 中包含组织(organization)、省市、地区、街道、邮编等组织类信息（必须严格仅为域名） |
| `e_cab_ov_requires_org` | OV 证书**必须**包含组织名 |
| `e_cab_iv_requires_personal_name` | IV（个人验证）证书必须有个人姓名 |
| `e_cert_policy_iv/ov_requires_country` | OV/IV 证书必须包含国家字段 |
| `e_ca_multiple_reserved_policy_oids` | 不允许同时使用多个 CABF 保留策略 OID |

### 4. DNS 名称 / SAN（主题备用名称）检测

这是 zlint 检测量最大的领域之一，覆盖域名规范性：

| 检测项 | 检测内容 |
|---|---|
| `e_dnsname_label_too_long` | 域名标签长度不得超过 63 字符 |
| `e_dnsname_contains_empty_label` | 不允许空标签（如 `foo..com`） |
| `e_dnsname_contains_bare_iana_suffix` | 不允许裸 TLD（如只签 `com`） |
| `e_dnsname_right_label_valid_tld` | 最右侧标签必须是有效 TLD |
| `e_dnsname_hyphen_in_sld` / `e_dnsname_underscore_in_sld` | SLD 中不允许连字符/下划线开头结尾 |
| `e_dnsname_underscore_in_trd` | 三级域名中不允许下划线（`_`） |
| `e_dnsname_bad_character_in_label` | 标签中不允许非法字符 |
| `e_dnsname_contains_prohibited_reserved_label` | 不允许保留标签 |
| `e_dnsname_wildcard_left_of_public_suffix` | **通配符必须覆盖整个公共后缀左侧**（不允许 `*.com`） |
| `e_dnsname_check_left_label_wildcard` | 通配符 `*.` 只允许出现在最左侧标签 |
| `e_dnsname_hyphen_in_sld` 等 | 国际化域名(IDN)相关：允许 punycode，不允许混淆字符 |
| `e_ext_san_dns_name_valid` | SAN 中的 DNS 名称必须可解析且符合规范 |
| `e_ext_ian_*` | IAN（签发者备用名称）扩展必须为 IA5 字符串、URI 格式合法、host 必须是 FQDN 或 IP |
| `e_arpa_domain_not_allowed` | 不允许使用 `.arpa` 保留域名（CABF BR 明确禁止） |

### 5. 公钥 / 签名算法 / 密钥强度

| 检测项 | 检测内容 |
|---|---|
| `e_rsa_mod_less_than_2048_bits` | **RSA 密钥长度不得小于 2048 位** |
| `e_rsa_public_exponent_too_small` / `e_rsa_public_exponent_not_odd` | RSA 公钥指数 E 必须为奇数且 ≥ 65537（实践中） |
| `e_rsa_mod_not_odd` | RSA 模数必须是奇数 |
| `e_ecdsa_allowed_ku` / `e_ecdsa_ee_invalid_ku` | ECDSA 证书的 KeyUsage 必须符合规范 |
| `e_dsa_cert_...` | DSA 密钥参数（p/q/g）合法性 |
| `e_signature_algorithm_not_supported` | 签名算法必须是已知/受支持的 |
| `w_rsa_public_exponent_too_small` | 指数过小的警告 |
| `e_dh_params_missing` | DH 证书必须包含 DH 参数 |
| `e_ec_curve_...` | 椭圆曲线必须为命名曲线，不允许 SECG/WTLS 曲线 |
| `e_old_sub_cert_rsa_mod_less_than_1024_bits` | 2014 年前签发证书 RSA 不得小于 1024 位 |

### 6. 证书扩展（Extensions）检测

| 扩展 | 检测项 | 检测内容 |
|---|---|---|
| **BasicConstraints** | `e_basic_constraints_not_critical` | CA 证书的 BasicConstraints **必须标记为 critical** |
| | `w_basic_constraints_not_critical` | 叶子证书若包含也应 critical |
| | `e_is_ca` | 根/中间 CA 必须 `cA=TRUE` |
| **KeyUsage** | `e_ca_key_usage_missing` | CA 证书必须包含 KeyUsage |
| | `e_ca_key_usage_not_critical` | CA 证书的 KeyUsage 必须 critical |
| | `e_ca_key_cert_sign_not_set` | CA 证书必须设置 `keyCertSign` 位 |
| | `e_ca_crl_sign_not_set` | CA 证书必须设置 `cRLSign` 位 |
| | `e_ca_digital_signature_not_set` | CA 证书必须设置 `digitalSignature` 位 |
| | `e_sub_cert_key_usage_cert_sign` | 叶子证书**禁止**设置 `keyCertSign` |
| | `e_sub_cert_eku_server_auth_client_auth` | 不允许同时包含 serverAuth 和 clientAuth |
| | `e_eku_...` | EKU 中各用途（serverAuth/codeSigning 等）的适用规则 |
| **Subject Key Identifier** | `e_subject_key_identifier_missing` | 所有证书必须包含 SKI |
| | `w_subject_key_identifier_missing` | CA 证书必须包含 SKI（早期要求） |
| | `e_subject_key_identifier_not_20_bytes` / `e_skid_...` | SKI 必须是 20 字节 SHA-1 等规范形式 |
| **Authority Key Identifier** | `e_ext_authority_key_identifier_no_key_identifier` | AKI 必须包含 keyIdentifier |
| | `e_ext_authority_key_identifier_critical` | AKI 不允许标记 critical |
| | `e_ca_akid_key_identifier_missing` | CA 证书 AKI 必须与签发者 SKI 匹配 |
| **AIA（权威信息访问）** | `e_aia_ocsp_must_have_http_only` / `e_aia_ca_issuers_must_have_http_only` | AIA 中 URL 必须仅为 HTTP |
| | `e_aia_must_contain_permitted_access_method` | AIA 必须包含允许的访问方法 |
| | `e_aia_unique_locations` | AIA 中不允许重复位置 |
| | `e_ext_aia_access_location_missing` | AIA 条目必须包含 location |
| | `e_ext_aia_marked_critical` | AIA 不允许 critical |
| **CRL Distribution Points** | `e_crl_distrib_points_not_http` / `e_crl_distrib_points_marked_critical` | CDP 必须为 HTTP、不允许 critical |
| | `e_crlissuer_must_not_be_present_in_cdp` | CDP 中不允许包含 cRLIssuer |
| | `w_distribution_point_incomplete` | DP 必须完整（含 name + reasons + cRLIssuer 一致） |
| **Certificate Policies** | `e_ext_cert_policy_duplicate` | 证书策略不允许重复 |
| | `e_ext_cert_policy_disallowed_any_policy_qualifier` | anyPolicy 不允许带 qualifier |
| | `e_ext_cert_policy_contains_noticeref` | 不允许使用 noticeRef（仅允许 CPS/explicitText） |
| | `e_ext_cert_policy_explicit_text_*` | 策略显式文本必须为 UTF-8、NFC 规范化、不含控制字符、长度受限 |
| | `e_ext_cert_policy_..._ia5_string` | 显式文本类型限制（IA5String） |
| **OCSP No Check** | `w_ext_ocsp_no_check_...` | OCSP no-check 扩展的适用性 |
| **SCT（证书透明）** | `e_ext_sct_...` / `e_empty_sct_list` | SCT 扩展格式、空列表、重复等（RFC 6962） |
| **QC 合格证书** | `e_qcstatem_qccompliance_valid` 等 | ETSI QC 声明语句的格式合法性（见第 9 节） |

### 7. CRL（证书吊销列表）检测（`rfc/` 与 `cabf_br/`）

| 检测项 | 检测内容 |
|---|---|
| `e_crl_missing_crl_number` | CRL 必须包含 **CRL Number** 扩展（RFC 5280 要求） |
| `e_crl_has_authority_key_identifier` | CRL 必须包含 AKI 扩展 |
| `e_crl_has_next_update` | CRL 必须包含 nextUpdate 字段 |
| `e_crl_empty_revoked_certificates` / `e_crl_revoked_certificates_field_empty` | CRL 中 revokedCertificates 不允许为空 |
| `e_crl_revocation_time_not_after_this_update` | 吊销时间不能晚于 thisUpdate |
| `e_crl_valid_reason_codes` / `e_cabf_crl_valid_reason_codes` | 吊销原因码必须合法（0-10，且证书吊销原因不能是 0/1 未使用值等） |
| `e_crl_sigalgo_missing_null_params` | CRL 签名算法的 RSA 参数必须包含 NULL |
| `e_crl_number_range` | CRL Number 必须为非负整数且在 20 字节内 |
| `e_crl_next_update_invalid` | nextUpdate 必须晚于 thisUpdate（CABF 要求） |
| `e_crl_extensions` | CRL 扩展必须合法（CABF BR 规定 CRL 只能包含指定扩展） |
| `e_crl_auth_key_id_only_contains_keyid` | CRL 的 AKI 只能包含 keyIdentifier |
| `e_cabf_crl_reason_code_not_critical` | 吊销原因扩展不应 critical |
| `e_crl_this_update_in_future` | thisUpdate 不能在未来 |

### 8. OCSP 响应检测

OCSP 相关检测项（`lint/` 中有 `OcspResponseLint` 接口），检查 OCSP 响应的格式合规性。

### 9. ETSI 合格证书（QC）检测（`etsi/`，欧洲电子签名/印章证书）

ETSI EN 319 412-5 规范，专门检测**欧洲合格证书（Qualified Certificate）**的 `qcStatements` 扩展：

| 检测项 | 检测内容 |
|---|---|
| `e_qcstatem_qccompliance_valid` | `id-etsi-qcs-QcCompliance` 声明必须格式正确 |
| `e_qcstatem_qclimitvalue_valid` | QC 限制值（金额限制）声明必须正确编码 |
| `e_qcstatem_qcretentionperiod_valid` | 证书保留期声明必须合法 |
| `e_qcstatem_qcsscd_valid` | 私钥存储在安全签名创建设备(SSCD)的声明 |
| `e_qcstatem_qcstatement_*` | 各类 QC 语句的 OID 与内容合法 |
| `e_qcstatem_*_semantics` | 语义检查：如 QcCompliance + QcSSCD 的组合逻辑等 |
| `e_ext_qcstatem_...` | QC 扩展必须为 critical 等标记规则 |

### 10. Root Store 特有策略（Mozilla / Apple / Chrome / CABF EV）

| 来源 | 代表性检测 | 内容 |
|---|---|---|
| **Apple** | `e_tls_server_cert_valid_time_longer_than_398_days` | TLS 服务器证书有效期 ≤ 398 天 |
| | `e_server_auth_eku` | 服务器证书必须含 serverAuth EKU |
| | `w_..._trust_anchor` | Apple 根证书策略 |
| **Mozilla** | `e_mp_rsa_ee_...` | Mozilla 对 RSA 密钥长度、签名算法的要求（2048+） |
| | `e_mp_..._sha1` | 禁止 SHA-1 签名（除非特殊情况） |
| | `e_mp_..._validity` | Mozilla 对证书有效期的限制 |
| | `e_mp_root_...` | 根证书必须满足 Mozilla 根存储策略（如 KeyUsage、EKU 限制） |
| **Chrome** | `e_chrome_..._ct` | Chrome 对证书透明(CT)日志要求等 |
| **CABF EV** | `e_ev_..._policy_oid` | EV 证书必须包含**正确的 EV 策略 OID** |
| | `e_ev_..._subject_*` | EV 证书 Subject 必须包含组织名、国家等 |
| | `e_ev_..._validity` | EV 证书有效期限制 |
| | `e_ev_..._cabf_...` | EV 指南中的扩展验证要求 |

### 11. 代码签名（`cabf_cs_br/`）与 S/MIME（`cabf_smime_br/`）

| 检测项 | 检测内容 |
|---|---|
| `e_code_sign_..._validity` | 代码签名证书有效期限制（最长 39 个月） |
| `e_code_sign_..._eku` | 代码签名证书必须含 `codeSigning` EKU |
| `e_code_sign_..._timestamp` | 时间戳证书要求 |
| `e_code_sign_..._ku` | 代码签名证书 KeyUsage 限制（不允许 keyCertSign 等） |
| `e_smime_..._eku` | S/MIME 证书必须含 emailProtection EKU |
| `e_smime_..._san` | S/MIME 证书 SAN 必须为 rfc822Name 邮箱格式 |
| `e_smime_..._subject` | S/MIME 证书 Subject 要求（mailbox 等） |
| `e_smime_..._validity` | S/MIME 证书有效期（最长 825 天/7 年等） |

### 12. 社区检查（`community/`）与基础配置

| 检测项 | 检测内容 |
|---|---|
| `w_subject_common_name_included` | CN 不建议保留（迁移到 SAN） |
| `e_serial_number_...` | 序列号随机性/熵要求 |
| `e_ext_san_...` | SAN 中的通用名称合法性 |
| `e_..._critical_...` | 各类扩展 critical 标记的一致性 |
| `w_..._utc_time_...` | 时间格式的过渡期警告 |

---

## 四、执行机制要点

1. **框架预过滤**（`base.go`）：CABF_BR 来源的 lint 只对 **serverAuth 服务器证书**执行；CABF_SMIME_BR 只对邮件保护证书；CABF_CS_BR 只对代码签名证书——不匹配自动返回 `NA`。
2. **生效日期控制**：每条 lint 有 `EffectiveDate`（生效起始）和 `IneffectiveDate`（失效），证书签发日期不在此区间则返回 `NE`，这让规范版本更替非常平滑（例如 398 天规则只对 2020-09-01 后签发的证书生效）。
3. **名称约定**：lint 名称以 `e_` 开头只返回 error/warn 中的一种，以 `w_` 开头同理；`lint_` 前缀 + 文件名即 lint 标识。
4. **panic 保护**：任何 lint 执行 panic 都会被捕获并返回 `fatal`，保证单个 lint 崩溃不影响整体检测。

---

## 五、检测覆盖统计

当前项目 `v3/lints/` 下共约 **860+ 条 lint 规则**，其中：

| 目录 | 规则数（约） | 侧重点 |
|---|---|---|
| `rfc/` | ~250 | 通用标准符合性（最基础） |
| `cabf_br/` | ~330 | TLS 服务器证书（覆盖最广） |
| `etsi/` | ~120 | 欧洲合格证书 QC |
| `mozilla/` | ~30 | Mozilla 根存储策略 |
| `apple/` | ~40 | Apple 策略（含 398 天有效期） |
| `community/` | ~30 | 社区共识 |
| `chrome/` | ~10 | Chrome 策略 |
| `cabf_ev/` | ~30 | EV 证书 |
| `cabf_cs_br/`、`cabf_smime_br/` | ~20 | 代码签名 / S/MIME |
