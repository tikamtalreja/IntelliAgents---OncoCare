# Testing Guide

This guide walks judges through testing all three components of OncoCare Ally: the Patient Agent, the HCP Slack Agent, and the WhatsApp reminder loop via Twilio.

---

## 1. WhatsApp + Twilio Reminder Testing

The Twilio integration uses a sandbox environment. To receive WhatsApp reminders on your own phone, you need to register your number with the sandbox first.

### Setup

1. **Add the Twilio sandbox number to your phone contacts:**
```
   +1 (415) 523-8886
```

2. **Send the join code via WhatsApp** to that number (this verifies your number with our sandbox):
```
   join happily-local
```

3. **Update your phone number** on the patient Contact (Account) record in Salesforce.

4. **Create at least one Service Appointment** on that account, scheduled for **tomorrow or later**.

### Trigger the reminder batch

Open Developer Console → Execute Anonymous, and run:

```apex
Database.executeBatch(new OnCo_AppointmentReminderBatch(), 1);
```

### Validate

Check WhatsApp on your phone — you should receive a reminder message with a unique appointment code (e.g., `APT-Q7MBL`).

You can reply with:
- `YES APT-XXXXX` to confirm the appointment
- `NO APT-XXXXX` to cancel

The Service Appointment status updates in real time, and you'll receive an automated confirmation reply.

---

## 2. Patient Agent — OncoCare Ally

### Login as a patient

1. Switch to **Salesforce Classic** mode
2. Find the Contact named **Navya Agrawal**
3. Click **"Login as Experience User"**
4. Select the **Onco Global** community

### Test scenarios

#### Scenario A — Speciality knowledge (RAG)

Ask the agent:
> "Want to know about Radiation Oncology"

The agent grounds its answer in our curated speciality content rather than hallucinating.

#### Scenario B — Find a doctor and book an appointment

Sample conversation flow:

| Speaker | Message |
|---|---|
| Patient | want to find a doctor |
| Agent | _Asks for speciality, department, or facility_ |
| Patient | speciality |
| Agent | _Shows available speciality options_ |
| Patient | Oncology |
| Agent | _Shows doctors near patient's location. If none nearby, shows picklists to widen the search by city or narrow by sub-specialty_ |
| Patient | All locations, all sub-specialities — book an appointment with Dr. Deepa Rao for tomorrow 4 PM |
| Agent | _Books the appointment_ |

##### Test Case 1 — Search by speciality

- Speciality: **Oncology**
- Sub-specialities: **All sub-specialities**
- Cities: **All cities**
- Select: **Dr. Deepa Rao**
- Provide a preferred date when prompted
- Confirm to book

##### Test Case 2 — Search by hospital

- Search by: **Hospital**
- Hospital: **Tata Memorial Cancer Center**
- City: **All cities**
- Select: **Dr. Rajesh Sharma**
- Provide preferred date and time
- Confirm to book

#### Scenario C — Manage upcoming appointments

| Speaker | Message |
|---|---|
| Patient | can you show me all upcoming appointments |
| Agent | _Renders all appointments in a list card_ |
| Patient | reschedule appointment SA-XXXX to [new date/time] |
| Agent | _Reschedules if no conflict; otherwise shows a conflict card and asks for a different slot_ |
| Patient | cancel appointment SA-XXXX |
| Agent | _Cancels the appointment and confirms_ |

---

## 3. HCP Agent — OncoCare Doc Assist on Slack

### Login

Log in to Slack using the email provided during the idea submission.

### Prerequisites

Make sure at least one appointment is scheduled for **Dr. Deepa Rao** (you can create one through the patient agent in Step 2 above).

### Test conversation flow

| Speaker | Message |
|---|---|
| Doctor | show all my upcoming appointments |
| Agent | Please provide your unique ID first |
| Doctor | HCP-001 |
| Agent | Are you Dr. Deepa Rao? |
| Doctor | yes |
| Agent | _Retrieves all appointments for the day_ |
| Doctor | cancel appointment SA-XXXX |
| Agent | _Cancels the appointment_ |

---

## End-to-end flow demonstration

For the most complete test, run them in this order:
1. Book an appointment via the **Patient Agent** for tomorrow
2. Run the **WhatsApp reminder batch** — patient gets reminded
3. Patient replies via **WhatsApp** to confirm or cancel
4. Doctor logs into **Slack** and sees the up-to-date list

This demonstrates that all three channels (web agent, WhatsApp, Slack) share the same single dispatcher and stay in sync.
