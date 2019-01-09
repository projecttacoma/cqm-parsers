library MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients version '7.2.002'

using QDM version '5.3'

codesystem "SNOMEDCT:2013-09": 'urn:oid:2.16.840.1.113883.6.96' version 'urn:hl7:version:2013-09'

valueset "ONC Administrative Sex": 'urn:oid:2.16.840.1.113762.1.4.1'
valueset "Race": 'urn:oid:2.16.840.1.114222.4.11.836'
valueset "Ethnicity": 'urn:oid:2.16.840.1.114222.4.11.837'
valueset "Payer": 'urn:oid:2.16.840.1.114222.4.11.3591'
valueset "Discharge To Acute Care Facility": 'urn:oid:2.16.840.1.113883.3.117.1.7.1.87'
valueset "Encounter Inpatient": 'urn:oid:2.16.840.1.113883.3.666.5.307'
valueset "Psychiatric/Mental Health Patient": 'urn:oid:2.16.840.1.113883.3.117.1.7.1.299'
valueset "Emergency Department Visit": 'urn:oid:2.16.840.1.113883.3.117.1.7.1.292'

code "Patient deceased during stay (discharge status = dead) (finding)": '371828006' from "SNOMEDCT:2013-09" display 'Patient deceased during stay (discharge status = dead) (finding)'

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

define "Initial Population":
	"ED Visit"

define "Measure Population":
	"Initial Population"

define "Stratification 1":
	"ED Visit" EDVisit
		where EDVisit.principalDiagnosis in "Psychiatric/Mental Health Patient"

define "Stratification 2":
	"ED Visit" EDVisit
		where EDVisit.dischargeDisposition in "Discharge To Acute Care Facility"

define "Stratification 3":
	"ED Visit" EDVisit
		where not ( EDVisit.principalDiagnosis in "Psychiatric/Mental Health Patient" )
			and not ( EDVisit.dischargeDisposition in "Discharge To Acute Care Facility" )

define "Measure Population Exclusions":
	( "ED Visit" EDVisit
			where EDVisit.dischargeDisposition ~ "Patient deceased during stay (discharge status = dead) (finding)"
	)
		union ( "ED Visit" EDVisit
				with ["Encounter, Performed": "Encounter Inpatient"] Encounter
					such that EDVisit.relevantPeriod ends 1 hour or less before or on start of Encounter.relevantPeriod
		)

define "ED Visit":
	["Encounter, Performed": "Emergency Department Visit"] EDVisit
		where EDVisit.relevantPeriod during "Measurement Period"

define function "Measure Observation"(Encounter "Encounter, Performed"):
	duration in minutes of Encounter.relevantPeriod
