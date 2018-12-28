library DiabetesMedicalAttentionforNephropathy version '6.1.001'

using QDM version '5.3'

include Hospice version '0.1.000' called Hospice
include MATGlobalCommonFunctions version '1.0.000' called Global

valueset "ONC Administrative Sex": 'urn:oid:2.16.840.1.113762.1.4.1'
valueset "Race": 'urn:oid:2.16.840.1.114222.4.11.836'
valueset "Ethnicity": 'urn:oid:2.16.840.1.114222.4.11.837'
valueset "Payer": 'urn:oid:2.16.840.1.114222.4.11.3591'
valueset "ACE Inhibitor or ARB": 'urn:oid:2.16.840.1.113883.3.526.3.1139'
valueset "Annual Wellness Visit": 'urn:oid:2.16.840.1.113883.3.526.3.1240'
valueset "Diabetes": 'urn:oid:2.16.840.1.113883.3.464.1003.103.12.1001'
valueset "Diabetic Nephropathy": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1004'
valueset "Dialysis Education": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1016'
valueset "Dialysis Services": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1013'
valueset "ESRD Monthly Outpatient Services": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1014'
valueset "Face-to-Face Interaction": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1048'
valueset "Glomerulonephritis and Nephrotic Syndrome": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1018'
valueset "Home Healthcare Services": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1016'
valueset "Hypertensive Chronic Kidney Disease": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1017'
valueset "Kidney Transplant": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1012'
valueset "Office Visit": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1001'
valueset "Other Services Related to Dialysis": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1015'
valueset "Preventive Care Services - Established Office Visit, 18 and Up": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1025'
valueset "Preventive Care Services-Initial Office Visit, 18 and Up": 'urn:oid:2.16.840.1.113883.3.464.1003.101.12.1023'
valueset "Proteinuria": 'urn:oid:2.16.840.1.113883.3.526.3.1003'
valueset "Urine Protein Tests": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1024'
valueset "Vascular Access for Dialysis": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1011'
valueset "Kidney Failure": 'urn:oid:2.16.840.1.113883.3.464.1003.109.12.1028'

parameter "Measurement Period" Interval<DateTime>

context Patient

define "SDE Ethnicity":
	["Patient Characteristic Ethnicity": "Ethnicity"]

define "SDE Payer":
	["Patient Characteristic Payer": "Payer"]

define "SDE Race":
	["Patient Characteristic Race": "Race"]

define "SDE Sex":
	["Patient Characteristic Sex": "ONC Administrative Sex"]

define "Renal Procedures":
	( ["Procedure, Performed": "Kidney Transplant"]
			union ["Procedure, Performed": "Vascular Access for Dialysis"]
			union ["Procedure, Performed": "Dialysis Services"]
	)

define "Renal Interventions":
	["Intervention, Performed": "Other Services Related to Dialysis"]
		union ["Intervention, Performed": "Dialysis Education"]

define "Qualifying Encounters":
	( ["Encounter, Performed": "Office Visit"]
		union ["Encounter, Performed": "Face-to-Face Interaction"]
		union ["Encounter, Performed": "Preventive Care Services - Established Office Visit, 18 and Up"]
		union ["Encounter, Performed": "Preventive Care Services-Initial Office Visit, 18 and Up"]
		union ["Encounter, Performed": "Home Healthcare Services"]
		union ["Encounter, Performed": "Annual Wellness Visit"] ) ValidEncounter
		where ValidEncounter.relevantPeriod during "Measurement Period"

define "Protein Urea Lab Test":
	["Laboratory Test, Performed": "Urine Protein Tests"] ProteinUrea
		where ProteinUrea.result is not null

define "Nephropathy Diagnoses":
	( ["Diagnosis": "Hypertensive Chronic Kidney Disease"]
		union ["Diagnosis": "Kidney Failure"]
		union ["Diagnosis": "Glomerulonephritis and Nephrotic Syndrome"]
		union ["Diagnosis": "Diabetic Nephropathy"]
		union ["Diagnosis": "Proteinuria"] ) NephropathyDiagnoses
		where NephropathyDiagnoses.prevalencePeriod overlaps "Measurement Period"

define "ESRD Encounter":
	["Encounter, Performed": "ESRD Monthly Outpatient Services"]

define "Nephropathy Screenings":
	"Renal Procedures"
		union "Renal Interventions"
		union "ESRD Encounter"
		union ( "Protein Urea Lab Test" ) NephropathyScreenings
			where NephropathyScreenings.relevantPeriod during "Measurement Period"

define "Has Hospice":
	Hospice."Has Hospice"

define "Active ACEI or ARB Medications":
	["Medication, Active": "ACE Inhibitor or ARB"] ACEIorARB
		where ACEIorARB.relevantPeriod overlaps "Measurement Period"

define "Initial Population":
	exists ["Patient Characteristic Birthdate"] BirthDate
		where Global."CalendarAgeInYearsAt"(BirthDate.birthDatetime, start of "Measurement Period")>= 18
			and Global."CalendarAgeInYearsAt"(BirthDate.birthDatetime, start of "Measurement Period")< 75
			and exists ( "Qualifying Encounters" )
			and exists ( ["Diagnosis": "Diabetes"] DiabetesDx
					where DiabetesDx.prevalencePeriod overlaps "Measurement Period"
			)

define "Denominator":
	"Initial Population"

define "Numerator":
	exists ( "Active ACEI or ARB Medications" )
		or exists ( "Nephropathy Diagnoses" )
		or exists ( "Nephropathy Screenings" )

define "Denominator Exclusions":
	"Has Hospice"
